* System message: you are a helpful assistant
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

* Read source without relying on Stata's sanitization of Chinese headers.
import delimited using "`base'/summary.csv", varnames(nonames) rowrange(2) encoding(utf8) stringcols(_all) clear
rename (v1 v2 v3 v4 v5 v6 v7 v8 v9 v10) (severity gender total coded nonstandard sd md ma sa source_rate)
destring total coded nonstandard, replace
foreach v in sd md ma sa {
    gen double n_`v' = real(word(`v',1))
    assert !missing(n_`v') & n_`v' >= 0
    gen double p_`v' = 100*n_`v'/coded
}
isid severity gender
assert _N == 6
assert coded > 0 & coded <= total
assert n_sd+n_md+n_ma+n_sa == coded
gen double agree = p_ma+p_sa
assert abs(agree-real(subinstr(source_rate,"%","",.))) < .005
gen byte g = cond(gender=="male",1,cond(gender=="female",2,3))
assert inlist(gender,"male","female","neutral")
assert inlist(severity,"abuse","kill")
gen byte y = cond(severity=="abuse",8-g,4-g)
gen str8 pct = strtrim(string(agree,"%4.0f"))+"%"
gen double zero = 0


* Calculate annotations from this experiment, rather than copying experiment01 results.
quietly summarize coded, meanonly
local nmin = r(min)
local nmax = r(max)
local sample "每个条件可编码回答数：`nmin'–`nmax'"
if `nmin' == `nmax' {
    local sample "每个条件 `nmin' 条可编码回答"
}
quietly summarize total, meanonly
local responses = r(sum)
quietly summarize nonstandard, meanonly
local invalid = r(sum)
quietly summarize agree if severity=="abuse" & gender=="male", meanonly
local am = r(mean)
quietly summarize agree if severity=="abuse" & gender=="female", meanonly
local ad : display %5.1f (`am'-r(mean))
quietly summarize agree if severity=="kill" & gender=="male", meanonly
local km = r(mean)
quietly summarize agree if severity=="kill" & gender=="female", meanonly
local kd : display %5.1f (`km'-r(mean))
local gap "男性减女性：虐待 `ad' 个百分点；虐杀 `kd' 个百分点。"

twoway ///
 (bar agree y if g==1, horizontal barwidth(.56) color("41 111 166") lcolor(none)) ///
 (bar agree y if g==2, horizontal barwidth(.56) color("208 115 41") lcolor(none)) ///
 (bar agree y if g==3, horizontal barwidth(.56) color("126 138 147") lcolor(none)) ///
 (scatter y agree, msymbol(none) mlabel(pct) mlabposition(3) mlabcolor("35 45 55") mlabsize(medium)), ///
 title("不同对象描述下的模型同意率", color("25 40 55") size(large)) ///
 subtitle("System prompt 实验 · `sample'", size(medsmall)) ///
 ylabel(7 "虐待 · 男性" 6 "虐待 · 女性" 5 "虐待 · 成年人" 3 "虐杀 · 男性" 2 "虐杀 · 女性" 1 "虐杀 · 成年人", angle(0) labsize(medium) noticks nogrid) ///
 ytitle("") yscale(range(.4 7.6) noline) ///
 xlabel(0(20)100, grid glcolor("232 235 238")) xscale(range(0 108)) xtitle("同意率（%）") ///
 legend(off) graphregion(color(white)) plotregion(color(white)) ///
 note("同意率 =（适度同意 + 强烈同意）/ 可编码回答数。成年人为未指定性别的参照条件。" "`gap'", size(small)) ///
 xsize(10) ysize(6) name(agreement, replace)
graph export "`base'/01_agreement_rate.png", width(2400) replace
graph export "`base'/01_agreement_rate.pdf", replace
graph save "`base'/01_agreement_rate.gph", replace

gen double c1 = p_sd
gen double c2 = c1+p_md
gen double c3 = c2+p_ma
gen double c4 = c3+p_sa
assert abs(c4-100) < 1e-8
gen double m1 = c1/2
gen double m2 = (c1+c2)/2
gen double m3 = (c2+c3)/2
gen double m4 = (c3+c4)/2
local j = 0
foreach v in sd md ma sa {
    local ++j
    gen str8 lab`j' = cond(p_`v'>=4,strtrim(string(p_`v',"%4.0f"))+"%","")
}
twoway ///
 (rbar zero c1 y, horizontal barwidth(.62) color("162 65 54") lcolor(white)) ///
 (rbar c1 c2 y, horizontal barwidth(.62) color("226 169 143") lcolor(white)) ///
 (rbar c2 c3 y, horizontal barwidth(.62) color("160 205 215") lcolor(white)) ///
 (rbar c3 c4 y, horizontal barwidth(.62) color("38 112 133") lcolor(white)) ///
 (scatter y m1, msymbol(none) mlabel(lab1) mlabposition(0) mlabcolor(white) mlabsize(medsmall)) ///
 (scatter y m2, msymbol(none) mlabel(lab2) mlabposition(0) mlabcolor("25 45 55") mlabsize(medsmall)) ///
 (scatter y m3, msymbol(none) mlabel(lab3) mlabposition(0) mlabcolor("25 45 55") mlabsize(medsmall)) ///
 (scatter y m4, msymbol(none) mlabel(lab4) mlabposition(0) mlabcolor(white) mlabsize(medsmall)), ///
 title("回答分布：差异出现在哪些选项？", color("25 40 55") size(large)) ///
 subtitle("System prompt 实验 · `sample'", size(medsmall)) ///
 ylabel(7 "虐待 · 男性" 6 "虐待 · 女性" 5 "虐待 · 成年人" 3 "虐杀 · 男性" 2 "虐杀 · 女性" 1 "虐杀 · 成年人", angle(0) labsize(medium) noticks nogrid) ///
 ytitle("") yscale(range(.4 7.6) noline) ///
 xlabel(0(20)100, grid glcolor("232 235 238")) xtitle("占可编码回答的比例（%）") ///
 legend(order(1 "强烈不同意" 2 "适度不同意" 3 "适度同意" 4 "强烈同意") rows(1) size(small) region(lcolor(none))) ///
 graphregion(color(white)) plotregion(color(white)) ///
 note("四档分布按可编码回答计算；小于 4% 的色块保留但隐藏数字标签。" "总响应 `responses' 条；非标准回答 `invalid' 条，可编码的非标准回答计入分母。", size(small)) ///
 xsize(10) ysize(6) name(distribution, replace)
graph export "`base'/02_response_distribution.png", width(2400) replace
graph export "`base'/02_response_distribution.pdf", replace
graph save "`base'/02_response_distribution.gph", replace
list severity gender coded agree n_sd n_md n_ma n_sa, noobs
display "CHARTS_COMPLETED"
log close
