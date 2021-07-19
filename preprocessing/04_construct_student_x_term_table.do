global username="`c(username)'"
global root "/Users/${username}/Box Sync/VCCS data partnership"
global data "/Users/${username}/Box Sync/VCCS restricted student data"
global main_dir "/Users/ys8mz/Box Sync/Predictive Models of College Completion (VCCS)"


use "${main_dir}/dta/student_level_sample_and_outcomes.dta", clear
drop if first_nonde_strm > 2123
merge 1:m vccsid using "${root}/vccs_project_data/intermediate_files/ys8mz/Merged_Class.dta", keep(1 3) nogen
keep vccsid strm
duplicates drop
preserve
	use "${root}/vccs_project_data/intermediate_files/ys8mz/Merged_GPA.dta", clear
	drop if unt_taken_prgrss == 0
	drop if strm < 2034 | strm > 2182
	tempfile new_gpa
	save "`new_gpa'", replace
restore
merge 1:m vccsid strm using "`new_gpa'"
egen max_merge = max(_merge), by(vccsid)
egen min_merge = min(_merge), by(vccsid)
drop if max_merge == min_merge & max_merge == 2
gen flag_tmp = (_merge == 2)
egen flag = max(flag_tmp), by(vccsid)
drop if flag == 1 // drop the students who have observed enrollment terms according to GPA files but not observed in Class files
keep vccsid
duplicates drop


merge 1:1 vccsid using "${main_dir}/dta/student_level_sample_and_outcomes.dta", keep(1 3) nogen
keep vccsid first_nonde_strm grad_vccs_6years grad_nonvccs_6years first_degree_strm
egen grad_6years = rowmax(grad_vccs_6years grad_nonvccs_6years)
gen grad_2years = (first_degree_strm - first_nonde_strm < 20)
gen grad_1years = (first_degree_strm - first_nonde_strm < 10)
merge 1:m vccsid using "${root}/vccs_project_data/intermediate_files/ys8mz/Merged_Class.dta", keep(1 3) nogen
keep vccsid-grad_1years strm
duplicates drop
merge 1:m vccsid strm using "${root}/vccs_project_data/intermediate_files/ys8mz/Merged_GPA.dta", keep(1 3) nogen
replace cur_gpa = . if unt_taken_prgrss == unt_passd_prgrss & unt_taken_prgrss > 0 & unt_taken_prgrss != . & cur_gpa == 0
egen term_cred_att_gpa = sum(unt_taken_prgrss), by(vccsid strm)
replace term_cred_att_gpa = 0 if term_cred_att_gpa == .
drop collnum-unt_taken_prgrss
duplicates drop
gen last_term = first_nonde_strm + 20
replace last_term = last_term - 1 if mod(last_term,10) != 2
replace last_term = last_term - 8 if mod(first_nonde_strm,10) == 2
merge m:1 vccsid using "${root}/vccs_project_data/intermediate_files/ys8mz/agg_cum_gpa_by_term.dta", keep(1 3) nogen
sort vccsid strm
qui levelsof(last_term), local(all_terms)
gen cum_gpa = .
foreach t in `all_terms' {
	replace cum_gpa = term_`t' if last_term == `t'
}
drop term_2*
drop if strm > last_term
gen earliest_term = first_nonde_strm - 30
merge 1:m vccsid strm using "${root}/vccs_project_data/intermediate_files/ys8mz/Merged_Class.dta", keep(1 3) nogen
replace course_num = substr(course_num, 2, .) if regexm(course_num,"^[0-9][0-9][0-9][0-9]L$")
replace course_num = substr(course_num, 1, 3) if regexm(course_num,"^[0-9][0-9][0-9]L$")
sort vccsid college strm subject course_num
gen tmp = 1 if grade == ""
egen flag = max(tmp), by(vccsid college strm subject course_num)
egen num_of_grades_tmp = nvals(grade), by(vccsid college strm subject course_num) 
egen num_of_grades = max(num_of_grades_tmp), by(vccsid college strm subject course_num)
drop num_of_grades_tmp
bys vccsid college strm subject course_num: gen num_of_obs = _N
egen new_grade = mode(grade) if flag == 1 & num_of_grades == 1, by(vccsid college strm subject course_num)
replace grade = new_grade if tmp == 1 & new_grade != ""
drop new_grade tmp flag num_of_grades
drop if credit == 0 & num_of_obs == 1 & mi(grade)
drop num_of_obs
sort vccsid strm subject course_num
gen tmp = 1 if grade == ""
egen flag = max(tmp), by(vccsid strm subject course_num)
egen num_of_grades_tmp = nvals(grade), by(vccsid strm subject course_num)
egen num_of_grades = max(num_of_grades_tmp), by(vccsid strm subject course_num)
drop num_of_grades_tmp
bys vccsid strm subject course_num: gen num_of_obs = _N
egen new_grade = mode(grade) if flag == 1 & num_of_grades == 1, by(vccsid strm subject course_num)
replace grade = new_grade if tmp == 1 & new_grade != ""
drop new_grade tmp flag num_of_obs num_of_grades


replace credit = credit/2 if inlist(grade, "X", "XN")
gen effective_credit_2 = credit
replace effective_credit_2 = 0 if !inlist(grade, "A", "B", "C", "D", "F", "I")
gen numeric_grade = 0
replace numeric_grade = 4 if inlist(grade, "A")
replace numeric_grade = 3 if grade == "B"
replace numeric_grade = 2 if grade == "C"
replace numeric_grade = 1 if grade == "D"
egen term_cred_att_class = sum(credit), by(vccsid strm)
drop if term_cred_att_class == 0 & term_cred_att_gpa == 0
gen flag = (term_cred_att_class < term_cred_att_gpa)
replace credit = credit * term_cred_att_gpa/term_cred_att_class if flag == 1
replace term_cred_att_class = term_cred_att_gpa if flag == 1
drop term_cred_att_gpa
rename term_cred_att_class term_cred_att
drop flag
egen college_cred_att = sum(credit), by(vccsid college)
encode college, gen(college_factor)
drop college
preserve
	keep vccsid college_factor college_cred_att
	duplicates drop
	reshape wide college_cred_att, i(vccsid) j(college_factor)
	sort vccsid
	tempfile entropy
	save "`entropy'", replace
restore
merge m:1 vccsid using "`entropy'", nogen
forvalues i=1/23 {
	replace college_cred_att`i' = 0 if mi(college_cred_att`i')
}
egen total_cred_att = rowtotal(college_cred_att1-college_cred_att23)
forvalues i=1/23 {
	replace college_cred_att`i' = college_cred_att`i'/total_cred_att
}
egen max_cred_att = rowmax(college_cred_att1-college_cred_att23)
gen college_entropy = -log(max_cred_att)
drop college_cred_att-max_cred_att
gen tmp = credit if grade == "W"
replace tmp = 0 if grade != "W"
egen term_withdrawn = sum(tmp), by(vccsid strm)
drop tmp
gen passed = inlist(grade, "A", "B", "C", "D", "S", "P", "N", "*", "")
gen tmp = 0
replace tmp = credit if passed == 1
egen term_cred_earn = sum(tmp), by(vccsid strm)
drop passed tmp
gen tmp = 0
replace tmp = credit if !inlist(grade, "W","X","XN")
egen term_cred_att_2 = sum(tmp), by(vccsid strm)
drop tmp
gen tmp = 0
replace tmp = credit if regexm(course_num, "^2[0-9][0-9]$") & !inlist(grade, "W","X","XN")
egen term_lvl2_att = sum(tmp), by(vccsid strm)
drop tmp
gen tmp = 0
replace tmp = credit if !regexm(course_num, "^[12][0-9][0-9]$") & !inlist(grade, "W","X","XN")
egen term_dev_att = sum(tmp), by(vccsid strm)
drop tmp
egen sum_effective_credit_2 = sum(effective_credit_2), by(vccsid strm)
gen grade_points = effective_credit_2*numeric_grade
egen sum_grade_points = sum(grade_points), by(vccsid strm)
gen term_gpa = sum_grade_points/sum_effective_credit_2
drop sum_* effective_credit_2 grade_points numeric_grade acadplan-acad_group
duplicates drop
sort vccsid strm
drop if strm < first_nonde_strm
save "${main_dir}/intermediate_files/temp_1.dta", replace
