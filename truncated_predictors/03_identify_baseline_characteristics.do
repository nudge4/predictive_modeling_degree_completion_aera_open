// This script extracts the baseline characteristics of our full (truncated) analytic sample, which are then used to create Appendix Table A4 of the paper
use "C:\Users\ys8mz\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\full_data_6yr.dta", clear
keep vccsid enrolled_*
drop enrolled_pre
foreach t in "fa" "sp" "su" {
	foreach n in 1 2 3 4 5 6 {
		rename enrolled_`t'`n' enrolled_vccs_`t'`n'
	}
}
foreach t in "fa" "sp" "su" {
	foreach n in 1 2 3 4 5 6 {
		gen enrolled_all_`t'`n' = (enrolled_vccs_`t'`n' + enrolled_nsc_`t'`n' > 0)
	}
}
egen enrl_len_vccs = rowtotal(enrolled_vccs_*)
egen enrl_len_nsc = rowtotal(enrolled_nsc_*)
egen enrl_len_all = rowtotal(enrolled_all_*)
keep vccsid enrl_*
merge 1:1 vccsid using "C:\Users\ys8mz\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\full_data_truncated.dta", keep(2 3) nogen
keep vccsid valid first_nonde_strm enrl_* age_entry white afam hisp other male phe_*
drop enrl_intensity*
gen first_gen = (phe_1 + phe_2 + phe_3 > 0)
gen non_first_gen = (phe_4 + phe_5 + phe_6 + phe_7 > 0)
gen mi_first_gen = (first_gen == 0 & non_first_gen == 0)
gen female = 1-male
drop phe_*
order vccsid valid first_nonde_strm enrl_* age_entry white afam hisp other male female *first_gen
gen enrolled_nsc = (enrl_len_nsc > 0)
merge 1:1 vccsid using "C:\Users\ys8mz\Box Sync\Predictive Models of College Completion (VCCS)\dta\student_level_sample_and_outcomes.dta", keep(1 3) keepusing(first_degree_strm grad_*_6years deg_vccs_*_strm deg_nonvccs_*_strm) nogen
gen grad_6years = (grad_vccs_6years==1 & grad_nonvccs_6years==1)
egen first_vccs_degree_strm = rowmin(deg_vccs_*_strm)
egen first_nonvccs_degree_strm = rowmin(deg_nonvccs_*_strm)
drop first_vccs_degree_strm first_nonvccs_degree_strm
gen p1 = floor((first_degree_strm-first_nonde_strm)/10)
gen p2 = mod(first_degree_strm-first_nonde_strm,10)
replace p2 = 1 if p2 == 8
replace p2 = 2 if p2 == 9
gen time_to_deg = 3*p1+p2+1
sort vccsid
drop deg_vccs_* deg_nonvccs_* drop first_nonde_strm first_degree_strm p1 p2
order vccsid-grad_nonvccs_6years grad_6years
save "C:\Users\ys8mz\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\baseline_characteristics.dta", replace
