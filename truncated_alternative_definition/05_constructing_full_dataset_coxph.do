// The purpose of this script is to add additional columns to the truncated dataset created,
// so that the dataset could fit into the Python library which is used to contruct CoxPH models

global username="`c(username)'"
global main_dir "/Users/${username}/Box Sync/Predictive Models of College Completion (VCCS)"

use "${main_dir}/intermediate_files/full_data_truncated_alternative.dta", clear
gen strm_diff = last_term - first_nonde_strm
gen n2 = mod(strm_diff, 10)
replace n2 = n2-7 if n2 >=8
gen n1 = int(strm_diff/10)
gen num_terms = n1*3+n2+1
drop n1 n2 strm_diff
gen strm_diff = first_degree_strm - last_term
gen n2 = mod(strm_diff, 10)
replace n2 = n2-7 if n2 >=8
gen n1 = int(strm_diff/10)
gen times = n1*3+n2
drop n1 n2 strm_diff
assert times + num_terms <= 18 if times != .
gen event = !mi(first_degree_strm)

replace times = 18-num_terms if event == 0
keep valid available_fa1-event

save "${main_dir}/intermediate_files/full_data_truncated_alternative_survival.dta", replace
