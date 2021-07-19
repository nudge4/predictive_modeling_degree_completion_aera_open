/******************************************************************************* 
					CLASS MASTER USE FILES	- CLEANING					
*******************************************************************************/

	

*** Setting any macros 
local instate_juris = 900 	
	* a juris from 001-900 is in the state of VA. 
	* any juris value set above $instate_juris will be considered out-of-state


*** Reading in class term files which are created in ./raw_data_csv_to_dta.do
clear
local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
local filelist: list sort filelist
display `filelist'
foreach file of local filelist {
    di "`file'"
	zipuse "$raw_data/$filetype/dta files/`file'", clear
	
	assert vccsid!="." & vccsid!=""
		* if this returns an error, you are missing the vccsid for an observation. 
	
*** TERM ***

	assert quarter_code == "FA" | quarter_code == "SP" | quarter_code == "SU"
		* if this returns an error, then quarter_code contains an 
		* previously unknown value, which will require adjustment to
		* generation of term directly below
	
	generate term = ""
	replace term = "6_fae" if quarter_code == "FA"
	replace term = "3_spe" if quarter_code == "SP"
	replace term = "4_sue" if quarter_code == "SU"
	
*** LEC_LAB_CODE ***
	
	assert lec_lab_code == "L" | lec_lab_code == "." | lec_lab_code == ""
		* if this returns an error, you have a new/unknown value and will need 
		* edit the code below.
	
	replace lec_lab_code = "0" if lec_lab_code == "" | lec_lab_code == "."
	replace lec_lab_code = "1" if lec_lab_code == "L"
	
	destring lec_lab_code, replace  
	
*** COURSE (E.G. "ENG111") ***

	generate course = subject + course_num
	
	* merging in course titles from Course files 
	merge m:1 collnum psclass_num pscourse_num strm using ///
		"$built_crosswalks/course_title_crosswalk", ///
		keep(master match) nogenerate
	
*** ACAD_GROUP ***
	
	capture generate acad_group = ""
	assert acad_group == "DEV" | acad_group == "NDEV" | acad_group == ""

	* removing "L" from the end of courses which have a number associated 
	replace course_num = subinstr(course_num, "L","",.) if strpos(course_num, "L") == 4
	replace course_num = subinstr(course_num, "L","",.) if strpos(course_num, "L") == 5
	* fixing roman numeral values
	replace course_num = "1" if course_num == "I"
	replace course_num = "2" if course_num == "II"
	replace course_num = "3" if course_num == "III"
	replace course_num = "4" if course_num == "IV"
	
	* creating a new variable to hold only numeric values of course_num 
	generate course_num_numeric = course_num
	replace course_num_numeric = "" if regexm(course_num_numeric, "J|K|S|T|L")
	destring course_num_numeric, replace 
	
	* filling in acad_group var for terms when it is not present
	* i.e. prior to Spring 2018.  acad_group is left blank for 
	* observations without a value of course_num_numeric.
	replace acad_group = "DEV" if course_num_numeric < 100 & acad_group == ""
	replace acad_group = "NDEV" if acad_group == "" & !missing(course_num_numeric)

*** ACADPLAN *** 

	* crosswalk created using VCCS files 
	generate collnum_acadplan = collnum+"_"+acadplan
	replace collnum_acadplan = "284_624:7" if collnum_acadplan == "284_624   :7"
	replace collnum_acadplan = collnum_acadplan + "0" if ///
		strpos(collnum_acadplan,"280_") == 1 & length(collnum_acadplan) == 7
	
	merge m:1 collnum_acadplan using "$built_crosswalks/acadplan_crosswalk.dta", ///
		keep(master match) nogenerate
		
*** CLASS_END and CLASS_START (start spring 2005) ***

	* one date to fix before converting to %td
	capture generate class_end = "" 
	capture generate class_start = ""
	replace class_end = "06/26/2006" if class_end == "62/62/0060" & psclass_num == "37906"
	
	generate newdate = date(class_end, "MDY")
	format newdate %td
		
	drop class_end
	rename newdate class_end
	
	generate newdate = date(class_start, "MDY")
	format newdate %td
		
	drop class_start
	rename newdate class_start	
		
	*fixing weird end dates 
	replace class_end = td(09mar2011) if class_end == td(09mar3011) ///
			& psclass_num == "59650" & pscourse_num == "156833"
	replace class_end = td(02jul2012) if class_end == td(02jul2912) ///
			& psclass_num == "29780" & pscourse_num == "507323"
	replace class_end = td(11feb2014) if class_end == td(11feb2104) ///
			& psclass_num == "40394" & pscourse_num == "160819"
	replace class_end = td(24oct2014) if class_end == td(24oct2041) ///
			& psclass_num == "42835" & pscourse_num == "127174"
	replace class_end = td(28may2016) if class_end == td(28may5016) ///
			& psclass_num == "26968" & pscourse_num == "220836"
	replace class_end = td(28may2016) if class_end == td(28may5016) ///
			& psclass_num == "26803" & pscourse_num == "223936"
	replace class_end = td(25jan2017) if class_end == td(25jan2207) ///
			& psclass_num == "64600" & pscourse_num == "030253"
	replace class_end = td(30sep2017) if class_end == td(30sep3017) ///
			& psclass_num == "49933" & pscourse_num == "561286" 
	replace class_end = td(11may2011) if class_end == td(11may4201) ///
			& (psclass_num == "41075" | psclass_num == "41510" | psclass_num == "41666" ///
			| psclass_num == "41695") & (pscourse_num == "135716" ///
			| pscourse_num == "136070" | pscourse_num == "136118" ///
			| pscourse_num == "511189")
	replace class_end = td(28jul2013) if class_end == td(28jul2030) ///
			& psclass_num == "27420" & pscourse_num == "436790"
	replace class_end = td(19dec2016) if class_end == td(21nov9201) ///
			& psclass_num == "45115" & pscourse_num == "530441"
	replace class_start = td(17sep2012) if class_start == td(01sep1972) ///
			& psclass_num == "26137" & pscourse_num == "227733"
	replace class_end = td(03jan2020) if class_end == td(03jan2030) ///
			& psclass_num=="55397" & pscourse_num == "075149"
		
	
	** the "assert"s below will result in an error if you have any more strange values
		** of class_end or class_start that we haven't identified yet. 
	assert (year(class_end) > 2000 & year(class_end) < 2021) | missing(class_end) 
	assert (year(class_start) > 2000 & year(class_start) < 2021) | missing(class_start)
	
*** COLLNUM_TEXT ***

	merge m:1 collnum using "$built_crosswalks/collnum_names_codebook", ///
		keepusing(collnum_text)
	assert _merge==3
		* if this returns an error, then there is a new value of collnum
		* of which we are not aware.
	drop _m
	
	* filling in college if it's missing
	capture generate college = ""
	count if college == ""
	replace college = collnum_text if college == ""
	
	* find discrepencies between collnum and college
	generate dontmatch_collnum_college = 0
	replace dontmatch_collnum_college = 1 if college != collnum_text
	assert dontmatch_collnum_college == 0 if strm != "2114"
		* if this returns an error, there are discrepencies between college and 
		* collnum_text outside of Fall 2011 (which we have already identified)

*** CURR ***
	
	assert length(curr) == 3 | curr == ""
		* if a curr value has fewer than 3 digits, then leading zeros 
		* will need to be added.
		* there should be no curr values with more than 3 digits
		
			
	* adjusting curr values to be the second three digits for all observations
	* with an acadplan corresponding to a Career Studies Certificate (CSC)
	replace curr = substr(acadplan,5,3) if 	strpos(acadplan,"221") == 1 & ///
											length(acadplan) >= 7 & ///
											real(substr(acadplan,5,3)) > 102
	
	merge m:1 curr using "$built_crosswalks/curr_crosswalk", ///
		keep(master match) nogenerate

	replace acadplan_description = curr_text + " (from curr)" if acadplan_description == ""

*** DL_METHOD ***

	assert dl_method == "0" | dl_method == "1" | dl_method == "2" | dl_method == ""
		* if this returns an error, you have a new/unknown value of dl_method 
		* and will need to adjust the code below. 

	destring dl_method, replace
	replace dl_method = 0 if missing(dl_method)

*** GENDER ***
	
	assert gender == "F" | gender == "M" | gender=="U"
		* if this returns an error, you have a new/unknown value of gender 
		* and will need to adjust the code below. 

*** GRADE ***

	merge m:1 grade using "$built_crosswalks/grade_codebook", ///
		keepusing(grade_text) keep(master match) nogenerate

*** GRADING_BASIS (begins Spring 2015) ***

	capture generate grading_basis = ""
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
	
*** GRADE_DATE ***

	generate grade_date_year = ""
	capture generate grade_date = ""
	replace grade_date_year = substr(grade_date,7,10) if length(grade_date) == 10
	replace grade_date_year = substr(grade_date,7,8) if length(grade_date) == 8
	replace grade_date_year = "2008" if grade_date_year == "08"
	replace grade_date_year = "2007" if grade_date_year == "07"
	replace grade_date_year = "2008" if grade_date_year == "88"
	
	replace grade_date = substr(grade_date,1,6) 
	replace grade_date = grade_date + grade_date_year
	
	generate newdate = date(grade_date, "MDY")
	format newdate %td
		
	drop grade_date
	rename newdate grade_date

	* fixing mistakes (decision on what to change to based on other obvs with
	* same grade date and one class start and end)
	
	replace grade_date = td(01nov2007) if grade_date == td(01nov2004) ///
			& psclass_num == "67704" & pscourse_num == "504637"
	replace grade_date = td(23mar2010) if grade_date == td(23mar2019) ///
			& psclass_num == "20110" & pscourse_num == "252384"
	replace grade_date = td(29jun2016) if grade_date == td(29jun2019) ///
			& psclass_num == "26355" & pscourse_num == "143008"
	replace grade_date = td(29sep2017) if grade_date == td(29sep2019) ///
			& psclass_num == "39678" & pscourse_num == "146218"
	replace grade_date = td(30aug2013) if grade_date == td(30aug2023) ///
			& psclass_num == "25947" & pscourse_num == "248618"
	replace grade_date = td(29oct2013) if grade_date == td(29oct2030) ///
			& psclass_num == "10096" & pscourse_num == "505121"
	replace grade_date = td(02sep2005) if grade_date == td(02sep2205) ///
			& psclass_num == "46624" & pscourse_num == "028685"
	
*** INSTMOD ***

	merge m:1 instmod using "$built_crosswalks/instmod_codebook", ///
		keepusing(instmod_text) keep(master match) nogenerate

*** JURIS ***
	assert length(juris)==3 | juris==""
		* if this returns an error, there are values with juris less than (or more than)
		* 3 digits in the data which could impact the construction of juris_instate. 
		
	merge m:1 juris using "$built_crosswalks/juris_codebook", ///
		keepusing(juris_text) keep(master match) nogenerate

	
	generate juris_instate = real(juris) < `instate_juris'
	replace juris_instate = 0 if juris == ""
	
*** PROGRAM_LEVEL ***
	
	merge m:1 program_level using "$built_crosswalks/program_level_codebook", ///
		keepusing(degree degreetype na) ///
		keep(master match)

	rename degree intended_degree
	rename degreetype intended_degreetype 
	
	generate fresh_soph = ""
	replace fresh_soph = "fresh" if na == "(freshman)" 
	replace fresh_soph = "soph" if na == "(sophomore)"
	
	drop na
	
	assert _merge != 1
		* if this returns an error, there are values of program_level in raw Class files
		* without any corresponding values in `program_level' 
	drop _m
	
	
*** STRM ***
	
	destring strm, replace 
	assert !missing(strm)
		* if this returns an error, there are missing values of strm. Code to fill
		* in any missing values can be found in "student_build_master_use.do"	
		
*** Generating any missing vars across years ***

	capture generate home_campus = ""
	capture generate ps_session = ""
	capture generate psclass_num = ""
	capture generate pscourse_num = ""
	capture generate xdul = ""
	capture generate xssd_val = ""
	
*** ORDERING VARS ***

	order vccsid year term vccsid acadplan* acad_group college collnum course course_title ///
	collnum_text dontmatch_collnum_college class_start class_end contract_code ///
	course_num credit curr curr_text day_eve_code curr_degree dl_code dl_college ///
	dl_method  gender grade grade_text grade_date grading_basis ///
	grading_basis_text home_campus institution instmod instmod_text juris juris_text ///
	juris_instate lec_lab_code parent_campus_t program_level intended_degree ///
	intended_degreetype ps_session psclass_num pscourse_num qtr_head_code ///
	quarter_code scamp section session strm subject ///
	t_alpha_sort_key 
 
*** ADDING VARIABLE LABELS ***

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
		sheet(variable_labels_class) raw(old_name) clean(new_name) label(label) keepx namelabel
		
*** ADDING VALUE LABELS ***

	global value_label_vars "dl_method lec_lab_code"
	
	foreach var of global value_label_vars {
	
		encodefrom `var' using "$codebook/master_use_variable_labels.xlsx", ///
		filetype(excel) sheet(`var') raw(raw) clean(clean) label(label) allow_missing
		
	}	
	

*** DESTRINGING ***
	
	global destring_vars "year collnum dontmatch_collnum_college credit dl_college juris_instate program_level t_alpha_sort_key xssd_val cip" 
	
	foreach var of global destring_vars {
		
		capture destring `var' , replace
		
		}
	
*** SAVING INDIVIDUAL FILES ***
	
	local year=substr("`file'",2,4)
	local term=substr("`file'",7,5)
	drop file
	
	sort vccsid pscourse_num psclass_num
	zipsave "$build_data/$filetype/${filetype}_`year'_`term'", replace
			
}
