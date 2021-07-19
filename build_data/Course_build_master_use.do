/******************************************************************************* 
							COURSE MASTER USE FILES			
*******************************************************************************/

		
*** Setting any macros 

	local new_inst_race_start = "2093"
		// this is the first semester of new_inst_race. used in "assert" check.
	local comp_instmod_start = 2008
		// this is the first year of the variables component and instmod
	
*** Reading in Course term files which are created in ./raw_data_csv_to_dta.do
clear
local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
local filelist: list sort filelist
display `filelist'
set obs 1
gen n = 1
foreach file of local filelist {

	disp "`file'"
	zipappend using "$raw_data/$filetype/dta files/`file'"

	}
	drop if n==1
	drop n

	
*** TERM ***

	assert quarter_code == "FA" | quarter_code == "SP" | quarter_code == "SU"
		* if this returns an error, you have a winter term and will need to revise
		* the "term" variable and potentially some other parts of the code. 
	
	generate term = ""
	replace term = "6_fae" if quarter_code == "FA"
	replace term = "3_spe" if quarter_code == "SP"
	replace term = "4_sue" if quarter_code == "SU"
		
*** VCCSID ***
	
	*assert vccsid != "." & vccsid != "" if real(strm) >= 2052
		* if this returns an error, you are missing the instructor's vccsid for an observation. 
		* Update March 2020: files now include course observations that do not
		* include instructor vccsid, but can still be linked with Class files
		* using psclass_num / pscourse_num

*** LEC_LAB_CODE ***
	
	assert lec_lab_code == "L" | lec_lab_code == "." | lec_lab_code == ""
		* if this returns an error, you have a new/unknown value and will need 
		* edit the code below.
	
	replace lec_lab_code = "1" if lec_lab_code == "L"
	replace lec_lab_code = "0" if lec_lab_code == "." | lec_lab_code == ""

*** ACAD_GROUP ***

	assert acad_group == "DEV" | acad_group == "NDEV" | acad_group == ""

	* removing "L" from the end of courses which have a number associated 
	replace course_num = subinstr(course_num, "L","",.) if strpos(course_num, "L")==4
	replace course_num = subinstr(course_num, "L","",.) if strpos(course_num, "L")==5
	* fixing roman numeral values
	replace course_num="1" if course_num=="I"
	replace course_num="2" if course_num=="II"
	replace course_num="3" if course_num=="III"
	replace course_num="4" if course_num=="IV"
	
	* creating a new variable to hold only numeric values of course_num 
	generate course_num_numeric = course_num
	replace course_num_numeric = "" if regexm(course_num_numeric, "J|K|S|T|L")	
	replace course_num_numeric = substr("000", 1, 3 - length(course_num_numeric)) + course_num_numeric if length(course_num_numeric) <= 3
	destring course_num_numeric, replace 
	
	* filling in acad_group var for terms when it is not present
	* i.e. prior to Spring 2018.  acad_group is left blank for 
	* observations without a value of course_num_numeric.
	replace acad_group = "DEV" if course_num_numeric < 100 & acad_group == ""
	replace acad_group = "NDEV" if acad_group == "" & !missing(course_num_numeric)
	

*** BEGIN_TIME and END_TIME *** 

	replace begin_time = substr("0000", 1, 4 - length(begin_time)) + begin_time if length(begin_time) <= 4	
	replace end_time = substr("0000", 1, 4 - length(end_time)) + end_time if length(end) <= 4	
	
*** CENSUS_DATE ***

	generate newdate = date(census_date, "MDY")
	format newdate %td
	
	drop census_date
	rename newdate census_date	
	
	replace census_date = td(20mar2018) if census_date == td(20mar2108)
	replace census_date = td(12feb2011) if census_date == td(12feb2161)
	replace census_date = td(20jan2015) if census_date == td(20jan2165)
	replace census_date = td(06sep2017) if census_date == td(06sep2167)
	replace census_date = td(26jan2016) if census_date == td(26jan2466)
	replace census_date = td(12sep2011) if census_date == td(12sep3011)
	
	assert (year(census_date) > 2000 & year(census_date) <= 2021) | missing(census_date) ///
		| census_date == td(04oct2023) | census_date == td(20jul2027) ///
		| census_date == td(13dec2030) | census_date == td(20apr2045) 
			* if this results in an error, there are new (strange) values of
			* census_date that we weren't previously aware of 

*** CLASS_END and CLASS_START ***

	generate newdate = date(class_end, "MDY")
	format newdate %td
		
	drop class_end
	rename newdate class_end
		
	generate newdate = date(class_start, "MDY")
	format newdate %td
		
	drop class_start
	rename newdate class_start
	
	*fixing weird start/end dates 
	replace class_end = td(03jan2020) if class_end == td(03jan2030) ///
			& psclass_num=="55397" & pscourse_num == "075149"	
	
	assert (year(class_end) > 2000 & year(class_end) < 2021) | missing(class_end)
	assert (year(class_start) > 2000 & year(class_start) < 2021) | missing(class_start)
		* if this results in an error, there are strange values
		* of class_end or class_start that we haven't identified yet. 

*** COMPONENT *** 

	merge m:1 component using "$built_crosswalks/component_codebook", ///
		keepusing(component_text) keep(master match)
	assert _merge == 3 | (real(year) <= `comp_instmod_start')
		* if this results in an error, then there are values of component
		* in the data that aren't accounted for in the codebook table
	drop _m

*** GENDER *** 
		
	*rename gender gender_instructor
	assert gender == "F" | gender == "M" | gender == "U" | gender==""
		* if this returns an error, you have a new/unknown value of gender 
		* and will need to adjust the code below. 

*** GRADING_BASIS_TEXT *** 

	assert grading_basis == "DEV" | grading_basis == "GRD" | ///
			grading_basis == "PNP" | grading_basis == "TRN" | ///
			grading_basis == ""
		* if this returns an error, there are values of grading_basis
		* of which we are not currently aware
	count if grading_basis == "TRN"
	assert r(N) <= 1
		* if this returns an error, then there is more than one observation
		* with grading_basis=="TRN"
		
	generate grading_basis_text = ""
	replace grading_basis_text = "Developmental" if grading_basis == "DEV"
	replace grading_basis_text = "Graded" if grading_basis == "GRD"
	replace grading_basis_text = "Pass/Fail" if grading_basis == "PNP"

*** INSTMOD *** 
	
	merge m:1 instmod using "$built_crosswalks/instmod_codebook", ///
		keep(master match) 
	assert _merge == 3 | (real(year) <= `comp_instmod_start')
		* if this results in an error, then there are values of instmod
		* in the data that aren't accounted for in the codebook table
	drop _m 

*** RACE DUMMIES ***

		foreach race of varlist r_* hisp_fl {
				* recoding 0/1
			quietly replace `race'="1" if `race'=="Y"
			quietly replace `race'="0" if `race'=="N"
			
			assert `race' == "1" | `race'=="0" | `race'=="" | `race'=="."
				* if this returns an error, you have an unknown value of one of the race vars.
			
				* destringing and renaming
			quietly destring `race', replace
			
			rename `race' `race'_instructor
		}
		
*** NEW_INST_RACE *** 

	destring new_inst_race, replace 

	assert (new_inst_race >= 0 & new_inst_race <=8) | new_inst_race==. if strm > "`new_inst_race_start'"
	assert missing(new_inst_race) if strm <= "`new_inst_race_start'"
		* if this returns an error, there are values of new_race in the raw Course
		* files without any corresponding values in VCCS provided codebook	
		* values of new_race_instructor are missing prior to Fall 2009

*** COURSE ***

	generate course = subject + course_num
	
*** ADDITIONAL DATA CHECKS ***

	assert dl_method == "0" | dl_method == "1" | dl_method == "2" | dl_method == ""
		* if this returns an error, you have a new/unknown value of dl_method 
		* and will need to adjust the code below. 
		
	assert strm != "." & strm != ""
		* if this returns an error, there are missing values of strm. Code to fill
		* in any missing values can be found in "student_build_master_use.do"	
	
*** ADDING LABELS ***

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
		sheet(variable_labels_course) raw(old_name) clean(new_name) label(label) keepx namelabel

	global value_label_vars "lec_lab_code building_status days_taught dl_method faculty_code new_race_instructor"
	
	foreach var of global value_label_vars {
	
		encodefrom `var' using "$codebook/master_use_variable_labels.xlsx", ///
		filetype(excel) sheet(`var') raw(raw) clean(clean) label(label) allow_missing
		
	}	
	
*** ORDERING ***	

	order vccsid_instructor college collnum year term acad_group course ///
	begin_time end_time building_num building_status census_date class_start ///
	class_end component component_text course_num course_title credit crse_enrollment ///
	day_eve_code days_taught facility faculty_code gender hisp_fl home_campus ///
	institution instmod instmod_text k_alpha_sort_key lec_lab_code locatn ///
	new_race_instructor parent_campus_k ps_session psclass_num pscourse_num qtr_head_code ///
	quarter_code r_amind_alsk r_asian r_black r_hawpac r_hisp r_nspec r_white ///
	race room_num scamp section session strm subject 


*** DESTRINGING ***
	
	global variables "collnum year census_date class_start class_end credit crse_enrollment k_alpha_sort_key psclass_num pscourse_num xssd_val strm"
	
	foreach var of global variables {
		destring `var' , replace
	}

*** SAVING ***	

	** saving each individual year x term file
	local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
	local filelist: list sort filelist
	disp `filelist'
	replace file = file+".dta.zip"

	foreach file of local filelist {
	
	preserve
		keep if file=="`file'"
		local year=substr("`file'",2,4)
		local term=substr("`file'",7,5)
		drop file
			
		sort pscourse_num psclass_num
		zipsave "$build_data/$filetype/${filetype}_`year'_`term'", replace		
	restore
	}
	
