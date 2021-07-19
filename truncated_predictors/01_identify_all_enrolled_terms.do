// The purpose of this script is to identify for each student, all of the term indices (since the initial term) in which the student was enrolled in VCCS
global username="`c(username)'"
global root "/Users/${username}/Box Sync/VCCS data partnership"
global main_dir "/Users/ys8mz/Box Sync/Predictive Models of College Completion (VCCS)"


use "${main_dir}/intermediate_files/full_data_enrolled_terms.dta", clear
merge 1:1 vccsid using "${main_dir}/dta/student_level_sample_and_outcomes.dta", keep(1 3) keepusing(first_degree_strm) nogen
keep vccsid first_nonde_strm first_degree_strm enrolled_*
drop enrolled_pre
reshape long enrolled_@, i(vccsid first_nonde_strm first_degree_strm) j(term) string
gen yr = substr(term, 3, .)
destring yr, replace
sort vccsid yr term
bys vccsid yr: gen term_num = _n
replace term_num = term_num + 3 if mod(first_nonde_strm,10) == 2 & substr(term,1,2) == "fa"
replace term_num = term_num - 3 if mod(first_nonde_strm,10) == 3 & substr(term,1,2) == "su"
sort vccsid yr term_num
drop term_num
bys vccsid yr: gen term_num = _n
gen nth = (yr-1)*3 + term_num
keep if enrolled_ == 1
drop if nth == 18 // Drop the 18th term
gen last_yr = floor((first_degree_strm - first_nonde_strm) / 10)
gen last_term = mod(first_degree_strm - first_nonde_strm, 10)
replace last_term = 1 if last_term == 8
replace last_term = 2 if last_term == 9
gen last_nth = 3*last_yr + last_term
drop if last_nth < nth // Drop the terms after the define last term
keep vccsid first_nonde_strm nth
sort vccsid nth
isid vccsid nth

save "${main_dir}/intermediate_files/enrolled_nth.dta", replace
