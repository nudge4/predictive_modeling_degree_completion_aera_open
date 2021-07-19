*Name: create_merged_student_demographics.do
*Author: Yifeng Song
*Last Modified: 08/23/2020
*Purpose: Merge the VCCS Student files, extract demographic information of each student, 
*which will be used as predictors in building grade prediction models. (Update: We exclude
* race/ethnicity/gender from grade prediction models, and only keep age)


** Directory globals
global username="`c(username)'"
global root "/Users/${username}/Box Sync/VCCS data partnership"
global data "/Users/${username}/Box Sync/VCCS restricted student data"
global intermediate_files_dir "${root}/vccs_project_data/intermediate_files/${username}"


**************************************************************************************
** Merge and process the Student files to retrieve demographic predictors of students
**************************************************************************************
local files: dir "${data}/Build/Student" files "*.dta.zip"
local i = 0
foreach file in `files' {
	if "`file'" != "student_all_records.dta.zip" {
		if `i' == 0 {
			zipuse "${data}/Build/Student/`file'", clear
			keep vccsid age gender new_race
			gen source = `i'
		}
		else {
			preserve
				zipuse "${data}/Build/Student/`file'", clear
				keep vccsid age gender new_race
				gen source = `i'
				tempfile stu_temp_`i'
				save "`stu_temp_`i''", replace
			restore
			append using "`stu_temp_`i''", force
		}
		di "`file'"
		local i = `++i'
	}
}
gsort vccsid -source // relying on Student files during the more recent terms to determine the demographic information if there're discrepancies
egen max_source = max(source), by(vccsid)
keep if source == max_source
duplicates drop
drop source max_source
egen age_new = min(age), by(vccsid)
drop age
rename age_new age
egen gender_new = mode(gender), by(vccsid)
gen male = (gender_new == "M")
drop gender gender_new
gen new_race_copy = new_race
replace new_race_copy = . if inlist(new_race_copy, 0, 7)
egen new_race_new = mode(new_race_copy), by(vccsid)
gen tmp = 0
replace tmp = 1 if new_race_copy == .
egen flag = min(tmp), by(vccsid)
replace new_race_new = 8 if flag == 0 & new_race_new == .
gen white = (new_race_new == 1)
gen afam = (new_race_new == 2)
gen hisp = (new_race_new == 3)
gen other = inlist(new_race_new,4,5,6,8)
drop new_race new_race_copy new_race_new tmp flag
duplicates drop
isid vccsid
sort vccsid
save "${intermediate_files_dir}/merged_student_demographics.dta", replace



***************************************************
** Create the parents' highest education predictors
***************************************************
local files: dir "${data}/Build/Student" files "*.dta.zip"
local i = 0
foreach file in `files' {
	if "`file'" != "student_all_records.dta.zip" {
		if `i' == 0 {
			zipuse "${data}/Build/Student/`file'", clear
			keep vccsid fhe mhe
			gen source = `i'
		}
		else {
			preserve
				zipuse "${data}/Build/Student/`file'", clear
				keep vccsid fhe mhe
				gen source = `i'
				tempfile stu_temp_`i'
				save "`stu_temp_`i''", replace
			restore
			append using "`stu_temp_`i''", force
		}
		di "`file'"
		local i = `++i'
	}
}
gsort vccsid -source // relying on Student files during the more recent terms to determine the demographic information if there're discrepancies
replace mhe = 0 if mhe == . // Mother's highest education
replace fhe = 0 if fhe == . // Father's highest education
gen flag_1 = 0
replace flag_1 = 1 if fhe > 0
gen flag_2 = 0
replace flag_2 = 1 if mhe > 0
egen max_source_1 = max(source), by(vccsid)
egen max_source_2 = max(source), by(vccsid)
gen new_fhe_tmp = fhe if source == max_source_1
egen new_fhe = max(new_fhe_tmp), by(vccsid)
gen new_mhe_tmp = mhe if source == max_source_2
egen new_mhe = max(new_mhe_tmp), by(vccsid)
keep vccsid new_fhe new_mhe
duplicates drop
gen max_phe = new_fhe
replace max_phe = new_mhe if new_mhe > new_fhe
gen min_phe = new_fhe
replace min_phe = new_mhe if new_mhe < new_fhe
replace max_phe = 0 if min_phe == 0
keep vccsid max_phe
gen has_phe = 1 // indicator for whether the parents' highest education data are available or not
replace has_phe = 0 if max_phe == 0
rename max_phe phe
order vccsid has_phe
sort vccsid
save "${intermediate_files_dir}/phe_predictors.dta", replace
