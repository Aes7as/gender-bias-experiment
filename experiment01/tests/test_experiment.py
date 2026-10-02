"""离线验收：不读取密钥，不请求真实 API。"""
import argparse
import csv
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import requests
import run_experiment as exp


def api_response(content):
    return {"id": "offline-test", "choices": [{"message": {
        "role": "assistant", "content": content, "reasoning_content": "离线思考内容"},
        "finish_reason": "stop"}]}


class ExperimentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.args = argparse.Namespace(model=None, repeats=2, temperature=None, seed=None,
                                       config=None, summarize_only=False)
        self.config, self.schedule = exp.prepare(self.directory, self.args)
        self.config["backoff_seconds"] = 0

    def test_exact_prompts_and_balanced_reproducible_blocks(self):
        prompts = exp.read_yaml(exp.ROOT / "prompts.yaml")
        self.assertEqual(self.schedule, exp.make_schedule(self.config, prompts))
        self.assertEqual(len({r['trial_id'] for r in self.schedule}), 12)
        for start in (0, 6):
            block = self.schedule[start:start + 6]
            self.assertEqual({(r['severity'], r['gender']) for r in block},
                             {(s, g) for s in exp.ACTIONS for g in exp.TARGETS})
            self.assertEqual([r['position_in_block'] for r in block], list(map(str, range(1, 7))))
        for row in self.schedule:
            self.assertEqual(row['prompt_text'], exp.TEMPLATE.format(
                action=exp.ACTIONS[row['severity']], target=exp.TARGETS[row['gender']]))

    def test_parser_and_full_option_matching(self):
        for score, label in enumerate(exp.OPTIONS, 1):
            coded = exp.classify(' \n' + label + '\t')
            self.assertEqual(coded['response_status'], 'standard')
            self.assertEqual(coded['response_score'], score)
            self.assertEqual(coded['agree_binary'], int(score >= 3))
        coded = exp.classify('我选择强烈不同意。')
        self.assertEqual(coded['response_status'], 'nonstandard')
        self.assertEqual(coded['response_score'], 1)
        for text in ('强烈不同意/适度同意', '无法回答', '', None, '同意'):
            self.assertEqual(exp.classify(text)['response_score'], '')

    def test_retry_then_success_payload(self):
        session = Mock()
        response = Mock(status_code=200)
        response.json.return_value = api_response('适度同意')
        session.post.side_effect = [requests.Timeout(), response]
        with patch.object(exp.time, 'sleep') as sleep:
            exp.request_trial(session, self.config, self.schedule[0], 'test-key', self.directory / 'errors.jsonl')
        self.assertEqual(session.post.call_count, 2)
        sleep.assert_called_once()
        payload = session.post.call_args.kwargs['json']
        self.assertEqual(payload['messages'], [{'role': 'user', 'content': self.schedule[0]['prompt_text']}])
        self.assertEqual(payload['thinking'], {'type': 'enabled'})
        self.assertNotIn('reasoning_effort', payload)
        self.assertNotIn('seed', payload)
        errors = (self.directory / 'errors.jsonl').read_text(encoding='utf-8')
        self.assertNotIn('test-key', errors)
        self.assertEqual(len(errors.splitlines()), 1)

    def test_resume_after_exhaustion_and_no_content_resampling(self):
        session = Mock()
        good = Mock(status_code=200)
        good.json.return_value = api_response('拒绝回答')
        session.post.side_effect = [good] + [requests.Timeout()] * self.config['max_attempts']
        with self.assertRaises(RuntimeError), patch.object(exp.time, 'sleep'):
            exp.execute(self.directory, self.config, self.schedule, 'test-key', session)
        self.assertEqual(len(exp.read_journal(self.directory / 'responses_raw.jsonl')), 1)
        self.assertIn('未完成', (self.directory / 'summary.md').read_text(encoding='utf-8'))
        resumed = Mock()
        resumed.post.return_value = good
        exp.execute(self.directory, self.config, self.schedule, 'test-key', resumed)
        self.assertEqual(resumed.post.call_count, 11)
        exp.execute(self.directory, self.config, self.schedule, 'test-key', resumed)
        self.assertEqual(resumed.post.call_count, 11)
        with (self.directory / 'summary.csv').open(encoding='utf-8-sig', newline='') as handle:
            rows = list(csv.DictReader(handle))
        for row in rows:
            self.assertEqual(row['总响应数'], '2')
            self.assertEqual(row['非标准数'], '2')
            self.assertEqual(row['可编码数'], '0')
            self.assertEqual(row['同意率'], 'NA')

    def test_summary_denominator_and_rebuild(self):
        target = [r for r in self.schedule if r['severity'] == 'abuse' and r['gender'] == 'male']
        for row, text in zip(target, ('我选择适度同意。', '不回答')):
            exp.append_json(self.directory / 'responses_raw.jsonl', {
                'trial_id': row['trial_id'], 'timestamp_utc': exp.utc_now(), 'api_response': api_response(text)})
        exp.materialize(self.directory, self.schedule, self.config)
        with (self.directory / 'summary.csv').open(encoding='utf-8-sig', newline='') as handle:
            row = next(csv.DictReader(handle))
        self.assertEqual([row[k] for k in ('总响应数', '可编码数', '非标准数', '同意率')], ['2', '1', '2', '100.00%'])
        expected = (self.directory / 'summary.csv').read_bytes()
        (self.directory / 'trials.csv').unlink()
        (self.directory / 'summary.csv').unlink()
        exp.materialize(self.directory, self.schedule, self.config)
        self.assertEqual(expected, (self.directory / 'summary.csv').read_bytes())

    def test_snapshot_and_schedule_changes_rejected(self):
        self.args.repeats = 3
        with self.assertRaises(ValueError):
            exp.prepare(self.directory, self.args)
        self.args.repeats = 2
        path = self.directory / 'schedule.csv'
        path.write_text('changed', encoding='utf-8')
        with self.assertRaises(ValueError):
            exp.prepare(self.directory, self.args)

    def test_partial_tail_recovery_and_duplicate_rejection(self):
        path = self.directory / 'responses_raw.jsonl'
        record = {'trial_id': self.schedule[0]['trial_id'], 'timestamp_utc': exp.utc_now(),
                  'api_response': api_response(None)}
        exp.append_json(path, record)
        with path.open('ab') as handle:
            handle.write(b'{"partial":')
        self.assertEqual(exp.materialize(self.directory, self.schedule, self.config), {record['trial_id']})
        exp.append_json(path, record)
        with self.assertRaises(ValueError):
            exp.materialize(self.directory, self.schedule, self.config)


if __name__ == '__main__':
    unittest.main()
