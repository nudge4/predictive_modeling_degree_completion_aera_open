/* 
This do file compiles a list of all unique vccsids present in the Student files

This list of unique vccsids will be used to remove observations in the 
Graduation and NSC files that are not present in the Student files			*/

clear
local filelist: dir "$build_files/Student" files "*.dta.zip"
local filelist: list sort filelist
foreach file of local filelist {

	preserve
		
		zipuse vccsid using "$build_files/Student/`file'", clear
		
		duplicates drop 
		
		tempfile unique_students
		save `unique_students', replace
		
	restore
	
	append using `unique_students'
	}

duplicates drop
isid vccsid 
sort vccsid
zipsave "$working_data/unique_vccsid_student_files", replace
clear all
