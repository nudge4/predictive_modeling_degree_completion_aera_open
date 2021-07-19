// The purpose of this script is to identify all students in the study sample who enrolled in PVCC during the last term in the truncated time window

global username="`c(username)'"
global data "/Users/${username}/Box Sync/VCCS restricted student data"

clear
** Load the Build Student files one by one, and append it to the running merged file
local files : dir "${data}/Build/Student" files "*.dta"
foreach file in `files' {
	di "`file'"
	preserve
		use "${data}/Build/Student/`file'", clear
		keep vccsid strm college total_credit_hrs
		keep if college == "Piedmont Virginia"
		keep if total_credit_hrs > 0
		duplicates drop
		tempfile college_data
		save "`college_data'", replace
	restore
	append using "`college_data'", force
}
rename strm last_term
sort vccsid last_term
merge m:1 vccsid last_term using "C:\Users\ys8mz\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\full_data_truncated.dta", keep(3) keepusing(valid) nogen
tab valid
keep vccsid
gen pvcc = 1
sort vccsid
isid vccsid
save "C:\Users\ys8mz\Box Sync\Predictive Models of College Completion (VCCS)\intermediate_files\pvcc_ind.dta", replace
