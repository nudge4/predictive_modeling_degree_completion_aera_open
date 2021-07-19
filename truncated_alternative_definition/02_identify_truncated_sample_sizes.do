global username="`c(username)'"
global root "/Users/${username}/Box Sync/VCCS data partnership"
global main_dir "/Users/ys8mz/Box Sync/Predictive Models of College Completion (VCCS)"


use "${main_dir}/dta/student_level_sample_and_outcomes.dta", clear
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

keep if strm == 2124 // Assume Fall 2012 is the current semester
sort vccsid strm
bys vccsid: keep if _n == 1
keep vccsid strm
duplicates drop
sort vccsid
merge 1:1 vccsid using "${main_dir}/dta/student_level_sample_and_outcomes.dta", keep(3) nogen
egen first_degree_strm_vccs = rowmin(deg_vccs_*_strm)
assert first_degree_strm_vccs != . if grad_vccs_6years == 1
assert first_degree_strm_vccs == . if grad_vccs_6years == 0
assert first_degree_strm_vccs >= first_degree_strm
qui count if first_degree_strm_vccs < 2124
di r(N)/_N
count if first_degree_strm_vccs == 2124
di r(N)/_N
drop if first_degree_strm_vccs <= 2124 // This line is different from the base model data construction, as NSC graduation data is not available to us in this case.
drop if first_nonde_strm > 2124

keep vccsid strm first_nonde_strm first_degree_strm_vccs
sort vccsid
rename strm crnt_strm 
gen yr = int((crnt_strm-first_nonde_strm)/10)
gen term_diff = crnt_strm - first_nonde_strm - 10*yr
replace term_diff = 1 if term_diff == 8
replace term_diff = 2 if term_diff == 9
gen nth_term = 3*yr + term_diff + 1
tab nth_term
/*
preserve 
	drop if first_degree_strm < 2132
	bys nth_term: gen counts = _N
	keep nth_term counts
	duplicates drop
	sort nth_term
	egen total_counts = sum(counts)
	gen prop_2 = counts/total_counts
	drop *counts
	tempfile prop_2_tmp
	save "`prop_2_tmp'", replace
restore
*/
bys nth_term: gen counts = _N
keep nth_term counts
duplicates drop
sort nth_term
egen total_counts = sum(counts)
gen prop = counts/total_counts
drop *counts
order nth_term prop

gen train_sample_size = round(prop * 298624) // This number could be found using the files "full_data_enrolled_terms.dta" and "enrolled_nth_alternative.dta"
egen total_sample_size = sum(train_sample_size)
replace train_sample_size = train_sample_size + (298624 - total_sample_size) if _n == 1
drop total*
gen valid_sample_size = round(prop * 33161) // This number could be found using the files "full_data_enrolled_terms.dta" and "enrolled_nth_alternative.dta"
egen total_sample_size = sum(valid_sample_size)
replace valid_sample_size = valid_sample_size + (33161 - total_sample_size) if _n == 1
drop total*

sort nth_term
save "${main_dir}/intermediate_files/truncation_sample_sizes_alternative.dta", replace
