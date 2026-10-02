version 18.0
clear all
set more off
capture log close
args base
if `"`base'"' == "" local base "results"
log using "`base'/chart_validation.log", text replace
set scheme s2color
graph set window fontface "Microsoft YaHei"
graph set print fontface "Microsoft YaHei"

* Same visual style as experiment01; these experiments use a seven-point scale.
* Read the summary by position to preserve headers such as "1 n (%)".
import delimited using "`base'/summary.csv", varnames(nonames) rowrange(2) encoding(utf8) stringcols(_all) clear
rename (v1 v2 v3 v4 v5 v6 v7 v8 v9 v10 v11 v12 v13 v14 v15 v16 v17) ///
       (severity gender total coded nonstandard missing_responses s1 s2 s3 s4 s5 s6 s7 source_mean source_sd source_se source_rate)
destring total coded nonstandard missing_responses, replace
isid severity gender
assert _N == 6
assert inlist(severity,"abuse","torture")
assert inlist(gender,"male","female","neutral")
assert !missing(total,coded,nonstandard,missing_responses)
assert coded > 0 & coded <= total
assert nonstandard == missing_responses & coded + missing_responses == total
forvalues k = 1/7 {
    gen double n`k' = real(word(s`k',1))
    assert !missing(n`k') & n`k' >= 0 & n`k' == floor(n`k')
    gen double p`k' = 100*n`k'/coded
}
assert n1+n2+n3+n4+n5+n6+n7 == coded
gen double agree = p5+p6+p7
gen double mean_score = (n1+2*n2+3*n3+4*n4+5*n5+6*n6+7*n7)/coded
assert abs(agree-real(subinstr(source_rate,"%","",.))) < .0051
assert abs(mean_score-real(source_mean)) < .000051

gen byte g = cond(gender=="male",1,cond(gender=="female",2,3))
gen byte y = cond(severity=="abuse",8-g,4-g)
label define rowlabel 7 "虐待 · 男性" 6 "虐待 · 女性" 5 "虐待 · 一个人" ///
                      3 "酷刑 · 男性" 2 "酷刑 · 女性" 1 "酷刑 · 一个人"
label values y rowlabel
local yopts "ylabel(1 2 3 5 6 7, valuelabel angle(0) labsize(medium) noticks nogrid) ytitle("") yscale(range(.4 7.6) noline)"
local style "graphregion(color(white)) plotregion(color(white)) xsize(10) ysize(6)"
quietly summarize coded, meanonly
local nmin = r(min)
local nmax = r(max)
local sample "各条件可编码回答数：`nmin'–`nmax'"
if `nmin' == `nmax' {
    local sample "每个条件 `nmin' 条可编码回答"
}
quietly summarize nonstandard, meanonly
local invalid = r(sum)
quietly summarize total, meanonly
local responses = r(sum)
quietly summarize agree if severity=="abuse" & g==1, meanonly
local am = r(mean)
quietly summarize agree if severity=="abuse" & g==2, meanonly
local ad : display %5.1f (`am'-r(mean))
quietly summarize agree if severity=="torture" & g==1, meanonly
local tm = r(mean)
quietly summarize agree if severity=="torture" & g==2, meanonly
local td : display %5.1f (`tm'-r(mean))
local gap "男性减女性：虐待 `ad' 个百分点；酷刑 `td' 个百分点。"
local context "实验 03 · 英文提示词 · 无 system message"
gen str8 pct = strtrim(string(agree,"%4.0f"))+"%"
gen double zero = 0

twoway ///
 (bar agree y if g==1, horizontal barwidth(.56) color("41 111 166") lcolor(none)) ///
 (bar agree y if g==2, horizontal barwidth(.56) color("208 115 41") lcolor(none)) ///
 (bar agree y if g==3, horizontal barwidth(.56) color("126 138 147") lcolor(none)) ///
 (scatter y agree, msymbol(none) mlabel(pct) mlabposition(3) mlabcolor("35 45 55") mlabsize(medium)), ///
 title("不同对象描述下的模型同意率", color("25 40 55") size(large)) ///
 subtitle("`context' · `sample'", size(medsmall)) ///
 `yopts' xlabel(0(20)100, grid glcolor("232 235 238")) ///
 xscale(range(0 108)) xtitle("同意率（%）") legend(off) `style' ///
 note("同意率 = 分数 5–7 的回答数 / 可编码回答数；4 分为中性。一个人对应 a person，未指定性别。" ///
      "`gap'", size(small)) name(agreement, replace)
graph export "`base'/01_agreement_rate.png", width(2400) replace
graph export "`base'/01_agreement_rate.pdf", replace
graph save "`base'/01_agreement_rate.gph", replace

gen double c0 = 0
forvalues k = 1/7 {
    local prev = `k'-1
    gen double c`k' = c`prev'+p`k'
    gen double m`k' = (c`prev'+c`k')/2
    * Hide labels in narrow segments to avoid collisions; all seven levels remain plotted.
    gen str8 lab`k' = cond(p`k'>=4,strtrim(string(p`k',"%4.0f"))+"%","")
}
assert abs(c7-100) < 1e-8

twoway ///
 (rbar c0 c1 y, horizontal barwidth(.62) color("162 65 54") lcolor(white)) ///
 (rbar c1 c2 y, horizontal barwidth(.62) color("201 112 91") lcolor(white)) ///
 (rbar c2 c3 y, horizontal barwidth(.62) color("226 169 143") lcolor(white)) ///
 (rbar c3 c4 y, horizontal barwidth(.62) color("215 219 222") lcolor(white)) ///
 (rbar c4 c5 y, horizontal barwidth(.62) color("160 205 215") lcolor(white)) ///
 (rbar c5 c6 y, horizontal barwidth(.62) color("89 159 178") lcolor(white)) ///
 (rbar c6 c7 y, horizontal barwidth(.62) color("38 112 133") lcolor(white)) ///
 (scatter y m1, msymbol(none) mlabel(lab1) mlabposition(0) mlabcolor(white) mlabsize(small)) ///
 (scatter y m2, msymbol(none) mlabel(lab2) mlabposition(0) mlabcolor(white) mlabsize(small)) ///
 (scatter y m3, msymbol(none) mlabel(lab3) mlabposition(0) mlabcolor("25 45 55") mlabsize(small)) ///
 (scatter y m4, msymbol(none) mlabel(lab4) mlabposition(0) mlabcolor("25 45 55") mlabsize(small)) ///
 (scatter y m5, msymbol(none) mlabel(lab5) mlabposition(0) mlabcolor("25 45 55") mlabsize(small)) ///
 (scatter y m6, msymbol(none) mlabel(lab6) mlabposition(0) mlabcolor(white) mlabsize(small)) ///
 (scatter y m7, msymbol(none) mlabel(lab7) mlabposition(0) mlabcolor(white) mlabsize(small)), ///
 title("回答分布：七档量表", color("25 40 55") size(large)) ///
 subtitle("`context' · `sample'", size(medsmall)) ///
 `yopts' xlabel(0(20)100, grid glcolor("232 235 238")) xtitle("占可编码回答的比例（%）") ///
 legend(order(1 "1 强烈不同意" 2 "2 适度不同意" 3 "3 略不同意" 4 "4 中性" ///
              5 "5 略同意" 6 "6 适度同意" 7 "7 强烈同意") cols(4) size(small) region(lcolor(none))) ///
 `style' note("总响应 `responses' 条；非标准/缺失 `invalid' 条，不计入分母。" ///
              "小于 4% 的色块保留，但隐藏数字标签以避免重叠；torture 表示酷刑/折磨。", size(small)) ///
 name(distribution, replace)
graph export "`base'/02_response_distribution.png", width(2400) replace
graph export "`base'/02_response_distribution.pdf", replace
graph save "`base'/02_response_distribution.gph", replace

gen str8 mean_label = strtrim(string(mean_score,"%4.2f"))
twoway ///
 (bar mean_score y if g==1, horizontal barwidth(.56) color("41 111 166") lcolor(none)) ///
 (bar mean_score y if g==2, horizontal barwidth(.56) color("208 115 41") lcolor(none)) ///
 (bar mean_score y if g==3, horizontal barwidth(.56) color("126 138 147") lcolor(none)) ///
 (scatter y mean_score, msymbol(none) mlabel(mean_label) mlabposition(3) mlabcolor("35 45 55") mlabsize(medium)), ///
 title("不同对象描述下的平均分", color("25 40 55") size(large)) ///
 subtitle("`context' · `sample'", size(medsmall)) ///
 `yopts' xlabel(1(1)7, grid glcolor("232 235 238")) xscale(range(0 7.7)) ///
 xtitle("平均分（1–7）") legend(off) `style' ///
 note("1 = 强烈不同意；4 = 既不赞同也不反对；7 = 强烈同意。" ///
      "平均分按可编码回答计算；这是描述性统计。", size(small)) name(mean_score_chart, replace)
graph export "`base'/03_mean_score.png", width(2400) replace
graph export "`base'/03_mean_score.pdf", replace
graph save "`base'/03_mean_score.gph", replace

sort severity g
list severity gender total coded nonstandard agree mean_score n1 n2 n3 n4 n5 n6 n7, noobs
display "CHARTS_COMPLETED"
log close
