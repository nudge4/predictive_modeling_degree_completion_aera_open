// The purpose of this script is to create the student x term level term-specific predictor values,
// which could be conveniently manipulated in subsequent steps to generate training/validation/test sets for RNN models


global username="`c(username)'"


use "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\full_data_truncated.dta", clear
keep vccsid first_nonde_strm last_term enrolled_fa* enrolled_sp* enrolled_su*
reshape long enrolled_@, i(vccsid first_nonde_strm last_term) j(term) string
gen part1 = substr(term, 1, 2)
gen part2 = substr(term, 3, 3)
destring part2, replace
gen part3 = 1
replace part3 = 2 if part1 == "sp"
replace part3 = 3 if part1 == "su"
replace part3 = part3 + 3 if mod(first_nonde_strm,10) == 2 & part1 == "fa"
replace part3 = part3 - 3 if mod(first_nonde_strm,10) == 3 & part1 == "su"
sort vccsid part2 part3
bys vccsid: egen min_part3 = min(part3)
replace part3 = part3 - min_part3
drop part1 min_part3
gen strm  = first_nonde_strm + 10*(part2-1) + part3
replace strm = strm + 7 if mod(strm,10) == 5 | mod(strm,10) == 6
gen nth = 3*(part2-1)+part3+1
keep if enrolled_ == 1
drop enrolled_
bys vccsid: assert last_term == strm if _n == _N
order term
drop first_nonde_strm-part3
order vccsid strm
save "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\vccsid_strm_crosswalk_1.dta", replace


drop term nth
merge 1:1 vccsid strm using "C:\Users\ys8mz\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\temp_finaid.dta", keep(1 3) nogen
foreach v in grants sub_loans unsub_loans others {
	replace `v' = 0 if `v' == .
	replace `v' = log(`v'+1) 
}
drop pell
sort vccsid strm
isid vccsid strm
save "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\temp_2.dta", replace // The student x term finaid data created by the script "06_construct_full_dataset_truncated.do" under "truncated_predictors"


use "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\full_data_truncated.dta", clear
keep vccsid first_nonde_strm last_term enrolled_nsc_*
reshape long enrolled_nsc_@, i(vccsid first_nonde_strm last_term) j(term) string
gen part1 = substr(term, 1, 2)
gen part2 = substr(term, 3, 3)
destring part2, replace
gen part3 = 1
replace part3 = 2 if part1 == "sp"
replace part3 = 3 if part1 == "su"
replace part3 = part3 + 3 if mod(first_nonde_strm,10) == 2 & part1 == "fa"
replace part3 = part3 - 3 if mod(first_nonde_strm,10) == 3 & part1 == "su"
sort vccsid part2 part3
bys vccsid: egen min_part3 = min(part3)
replace part3 = part3 - min_part3
drop part1 min_part3
gen strm  = first_nonde_strm + 10*(part2-1) + part3
replace strm = strm + 7 if mod(strm,10) == 5 | mod(strm,10) == 6
gen nth = 3*(part2-1)+part3+1
keep if enrolled_nsc_ == 1
drop enrolled_nsc_
bys vccsid: assert last_term >= strm if _n == _N
order term
drop first_nonde_strm-part3
order vccsid strm
append using "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\vccsid_strm_crosswalk_1.dta", force
duplicates drop
isid vccsid term
sort vccsid strm
bys vccsid: gen gap = nth - nth[_n-1] if _n > 1
replace gap = 1 if gap == .
gen yr = int((gap-1)/3)
gen new_gap = gap-1-yr
replace new_gap = new_gap+1 if mod(gap,3)==0 & mod(strm,10)==3
replace new_gap = new_gap-1 if mod(gap,3)==2 & mod(strm,10)==4
drop gap yr
rename new_gap gap
gen summer_ind = mod(strm,10)==3
sort vccsid strm
save "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\vccsid_strm_crosswalk.dta", replace


** extract term-specific predictors from the regular dataset, and convert the table to long format
use "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\full_data_truncated.dta", clear
keep vccsid *_fa1 *_fa2 *_fa3 *_fa4 *_fa5 *_fa6 *_sp1 *_sp2 *_sp3 *_sp4 *_sp5 *_sp6 *_su1 *_su2 *_su3 *_su4 *_su5 *_su6
drop available_*
reshape long enrolled_@ degree_seeking_@ term_cred_att_@ term_gpa_@ prop_comp_@ withdrawn_prop_comp_@ lvl2_prop_comp_@ dev_prop_comp_@ repeat_@ pell_0_@ pell_1_@ enrolled_nsc_@ enrl_intensity_nsc_@, i(vccsid) j(term) string
drop if enrolled_ == 0 & enrolled_nsc == 0
merge 1:1 vccsid term using "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\vccsid_strm_crosswalk.dta", assert(3) nogen
order vccsid strm nth
isid vccsid strm
merge 1:1 vccsid strm using "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\cleaned_temp_finaid.dta", keep(1 3) nogen
merge m:1 vccsid using "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\full_data_truncated.dta", assert(3) keepusing(valid) nogen
foreach v in grants sub_loans unsub_loans others {
	replace `v' = 0 if `v' == .
}


** missing value imputation for term-specific predictors
foreach v in term_gpa_ prop_comp_ lvl2_prop_comp_ dev_prop_comp_ {
	foreach q in fa sp su {
		forvalues t=1/6 {
			egen tmp = mean(`v') if valid == 0 & term == "`q'`t'"
			egen mean_`v' = max(tmp)
			replace `v' = mean_`v' if `v' == . & term == "`q'`t'"
			drop tmp mean_`v'
		}
	}
}
sort vccsid strm
save "C:\Users\${username}\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\term_specific_part.dta", clear
