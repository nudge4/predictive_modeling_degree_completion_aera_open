

*******************************************************
*** Setting switches for which build scripts to run ***
*** with first option for running all eight scripts ***
*******************************************************

local switch_all 			= 0
local switch_Student		= 0
local switch_Class			= 0
local switch_Course			= 0
local switch_Employment		= 0
local switch_FinancialAid	= 0
local switch_GPA			= 1
local switch_Graduation		= 1
local switch_NSC			= 1 


*** Student files: 
*** within term, data is student x college level
*** sort on vccsid and collnum
if `switch_Student'==1 | `switch_all'==1 {

	local filelist: dir "$build_data/Student" files "*.dta.zip"
	local filelist: list sort filelist
	foreach file of local filelist {
	
		zipuse "$build_data/Student/`file'", clear
		count
		sort vccsid collnum
		zipsave "$build_data/Student/`file'", replace
		}
		}
		
*** Class files: 
*** within term, data is student x class section level (within course)
*** sort on vccsid and psclass_num
if `switch_Class'==1 | `switch_all'==1 {

	local filelist: dir "$build_data/Class" files "*.dta.zip"
	local filelist: list sort filelist
	foreach file of local filelist {
	
		zipuse "$build_data/Class/`file'", clear
		count
		sort vccsid psclass_num
		zipsave "$build_data/Class/`file'", replace
		}
		}
		
*** Course files: 
*** within term, data is section level 
*** sort on psclass_num
if `switch_Course'==1 | `switch_all'==1 {

	local filelist: dir "$build_data/Course" files "*.dta.zip"
	local filelist: list sort filelist
	foreach file of local filelist {
	
		zipuse "$build_data/Course/`file'", clear
		count
		sort psclass_num
		zipsave "$build_data/Course/`file'", replace
		}
		}	
		
*** Employment files: 
*** within quarter, data is student x employer level
*** sort on vccsid employer_name
if `switch_Employment'==1 | `switch_all'==1 {

	local filelist: dir "$build_data/Employment" files "*.dta.zip"
	local filelist: list sort filelist
	foreach file of local filelist {
	
		zipuse "$build_data/Employment/`file'", clear
		count
		sort vccsid employer_name
		zipsave "$build_data/Employment/`file'", replace
		}
		}	
		
*** FinancialAid files: 
*** within year, data is student x repper level
*** sort on vccsid repper
if `switch_FinancialAid'==1 | `switch_all'==1 {

	local filelist: dir "$build_data/FinancialAid" files "*.dta.zip"
	local filelist: list sort filelist
	foreach file of local filelist {
	
		zipuse "$build_data/FinancialAid/`file'", clear
		count
		sort vccsid repper
		zipsave "$build_data/FinancialAid/`file'", replace
		}
		}	
		
*** GPA files: 
*** within term, data is student x college level
*** sort on vccsid collnum
if `switch_GPA'==1 | `switch_all'==1 {

	local filelist: dir "$build_data/GPA" files "*.dta.zip"
	local filelist: list sort filelist
	foreach file of local filelist {
	
		zipuse "$build_data/GPA/`file'", clear
		count
		sort vccsid collnum
		zipsave "$build_data/GPA/`file'", replace
		}
		}			
		
*** Graduation files: 
*** within year, data is student x degree level
*** sort on vccsid acadplan
if `switch_GPA'==1 | `switch_all'==1 {

	local filelist: dir "$build_data/Graduation" files "*.dta.zip"
	local filelist: list sort filelist
	foreach file of local filelist {
	
		zipuse "$build_data/Graduation/`file'", clear
		count
		sort vccsid lstterm acadplan
		zipsave "$build_data/Graduation/`file'", replace
		}
		}	
		
		
*** NSC Enrollment and Graduation files: 
*** within year, data is student x enrollment record level
*** or student x degree record level
*** sort on vccsid enrol_begin enrol_end grad_date
if `switch_NSC'==1 | `switch_all'==1 {

	local filelist: dir "$build_data/NSC" files "*.dta.zip"
	local filelist: list sort filelist
	foreach file of local filelist {
	
		zipuse "$build_data/NSC/`file'", clear
		count
		capture sort vccsid enrol_begin enrol_end 
		capture sort vccsid grad_date
		zipsave "$build_data/NSC/`file'", replace
		}
		}			
