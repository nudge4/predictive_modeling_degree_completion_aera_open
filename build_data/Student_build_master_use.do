/******************************************************************************* 
							STUDENT MASTER USE FILES						
*******************************************************************************/


*** Reading in student files with all records created in ./data_appending.do
clear
local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
local filelist: list sort filelist
display `filelist'
set obs 1
gen n = 1
foreach file of local filelist {

	disp "`file'"
	zipuse "$raw_data/$filetype/dta files/`file'", clear
	
	assert vccsid != "." & vccsid != ""
		* if this returns an error, you are missing the vccsid for an observation. 
	
*** TERM ***

	assert quarter_code == "FA" | quarter_code == "SP" | quarter_code == "SU"
		* if this returns an error, then quarter_code contains an 
		* previously unknown value, which will require adjustment to
		* generation of term directly below
	
	gen term = ""
	replace term = "6_fae" if quarter_code == "FA"
	replace term = "3_spe" if quarter_code == "SP"
	replace term = "4_sue" if quarter_code == "SU"
	
*** ACADPLAN *** 

	* creating college x acadplan specific variable for merging purposes
	gen collnum_acadplan = collnum+"_"+acadplan
	
	* fixing acadplan values for NVCC, which end in "0" in the crosswalk
	* but not always in the student files
	replace collnum_acadplan = collnum_acadplan + "0" if ///
		strpos(collnum_acadplan,"280_")==1 & length(collnum_acadplan)==7
		
	* Fixing one-off strange values of acadplan
	replace collnum_acadplan = "284_624:7" if collnum_acadplan == "284_624   :7"
	
	* crosswalk created using VCCS files to include additional information
	* about acadplan
	merge m:1 collnum_acadplan using "$built_crosswalks/acadplan_crosswalk.dta", ///
		keep(master match)  
		drop _merge
	
	
*** CEEB CODES ***
	
	replace ceeb = substr("000000", 1, 6 - length(ceeb)) + ceeb if length(ceeb) <= 6 ///
		& ceeb!="DC279" & ceeb!="NV280" & ceeb!=""
		
	* merging in ceeb crosswalk
	
	merge m:1 ceeb using "$built_crosswalks/ceeb_crosswalk", keep(master match)
		drop _m
	
*** COLLNUM_LOCATION ***								 

	merge m:1 collnum parent_campus_a using "$built_crosswalks/parent_campus_a_codebook", ///
			keepusing(campus collnum_location)
	
		drop if _m == 2
		drop _m  		
	
*** CURR ***
	
	assert length(curr) == 3 | curr == ""
		* if a curr value has fewer than 3 digits, then leading zeros 
		* will need to be added.
		* there should be no curr values with more than 3 digits
		
	* adjusting curr values to be the second three digits for all observations
	* with an acadplan corresponding to a Career Studies Certificate (CSC)
	replace curr=substr(acadplan,5,3) if 	strpos(acadplan,"221")==1 & ///
											length(acadplan)>=7 & ///
											real(substr(acadplan,5,3)) > 102
		
	merge m:1 curr using "$built_crosswalks/curr_crosswalk", keep(master match)
	
	assert _m==3 | curr=="" | curr=="034"

		drop _m
		
		* replacing acadplan_description with curr_text if it is missing 
	replace acadplan_description = curr_text + " (from curr)" if acadplan_description==""
	
	* replace curr values "04A" with "044" to allow for destringing of curr
	replace curr="044" if curr=="04A" 
	
	
*** CIP *** 

	* Note: the inclusion of these two variables make it difficult 
	* for the build scripts to run; leaving out for now
	/*
	* Note that the variable cip was merged into the Student files
	* through the curr_crosswalk (see directly above)
	
	* First, titles for two-digit CIP (broad categories)
	gen pos = strpos(string(cip),".") - 1
	gen cip2 = substr(string(cip),1,pos) 
	replace cip2 = string(cip) if pos==0 | pos == -1 
	assert length(cip2)==1 | length(cip2)==2
	destring cip2, replace
	
	merge n:1 cip2 using "$built_crosswalks/cip2_title", keep(master match)
	
		assert real(curr) < 100 if _merge==1
		drop _merge
		
	* Next, titles and descriptios for specific CIP categories (most always 6-digit)
	tostring cip, replace
	merge n:1 cip using "$built_crosswalks/fullcip_title_description", ///
		keep(master match) keepusing(ciptitle)
		
		// There are some currs with only 2 digit CIPs
		replace ciptitle = cip2title if length(cip)==2 & _merge==1
		drop _merge
	*/
	
	
*** FP CODES ***									

	replace fp_code = "P" if fp_code == "A"
	replace fp_code = "F" if fp_code == "f"
	replace fp_code = "P" if fp_code == "p"
	
	assert fp_code == "P" | fp_code == "F" | fp_code == ""
		* if this returns an error, there is a new value of fp_code which has 
		* not been accounted for above. 
	
*** GENDER ***

	assert gender == "F" | gender == "M" | gender == "U"
		* if this returns an error, you have a new/unknown value of gender 
		* and will need to adjust the code above. 

*** HS GRAD YEAR ****

	replace hs_grad_year = "." if hs_grad_year == "NA" | hs_grad_year == "0" ///
		| hs_grad_year == "1900" | hs_grad_year == ""
		
	destring hs_grad_year, replace
	
	assert (hs_grad_year >= 1900 & hs_grad_year <= 2050) if hs_grad_year!=.
		* returns an error for high school graduation years that are 
		* way outside the current realm of possibilities

*** HS GPA ***

	replace hsgpa = "." if hsgpa == "NA"

*** JURIS ***	

	// in 2018-2019 updated file, there are 8 observations with juris = ""
	// (8 unique students across three terms)
	// this information may be filled in in future iterations? 
	// adding addition check to inspect additional missing values of juris
	// in the future 
	// Update as of March 2020: there are now 12 such students. 
	count if juris == ""
	assert r(N) <= 20
		
	assert length(juris) == 3 | juris == "" 
		* if this returns an error, there are values with juris less than (or more than)
		* 3 digits in the data which could impact the construction of juris_instate. 
		
	merge m:1 juris using "$built_crosswalks/juris_codebook", keepusing(juris_text)

		drop if _m == 2
		drop _m
	
	*if juris is less than 900, they're in VA
	gen juris_instate = 1 if juris < "900"
	replace juris_instate = 0 if juris_instate == .
	replace juris_instate = . if juris == ""
	
*** MIL_STATUS ***

	gen mil_status_text = ""
	
	replace mil_status_text = "No Response" if mil_status == " " | mil_status == "" & strm >= "2084"
		* any strm earlier than 2084 didn't have mil_status, so it's not that they 
		* didn't respond - prefer to leave as blank. 
	replace mil_status_text = "Not Indicated" if mil_status == "1"
	replace mil_status_text = "No Military Service" if mil_status == "2"
	replace mil_status_text = "Active" if inlist(mil_status,"A","B","C","D","E","F","T")
	replace mil_status_text = "Retired" if mil_status == "7"
	replace mil_status_text = "Dependent" if mil_status == "R"
	replace mil_status_text = "Spouse" if mil_status == "S"
	replace mil_status_text = "Veteran" if inlist(mil_status,"3","4","8","9","Q","V","Z")
	replace mil_status_text = "Reserve" if inlist(mil_status,"5","6","G","H","I","J") ///
		| inlist(mil_status,"K","L","M","N","O","P")
	replace mil_status_text = "Not a Veteran" if mil_status == "X"
	
	assert mil_status_text!="" if mil_status!=""

*** PREV_DEGREE ***								 		
	
	merge m:1 prev_degree using "$built_crosswalks/prev_degree_codebook", ///
		keepusing(prev_degree_text)

	*replacing the prev_degree_text with prev_degree if it doesn't match up with codebook
	replace prev_degree_text = prev_degree if prev_degree_text == "" & prev_degree != ""

		drop if _m == 2
		drop _m
	
	replace prev_degree="" if prev_degree=="."

*** PROGRAM_LEVEL ***							 		
	
	merge m:1 program_level using "$built_crosswalks/program_level_codebook", ///
		keepusing(degree degreetype na)
	
	assert _merge != 1
		* if this returns an error, there are values of program_level in raw Student files
		* without any corresponding values in `program_level' 

	rename degree intended_degree
	rename degreetype intended_degreetype 
	
	gen fresh_soph = ""
		replace fresh_soph = "fresh" if na == "(freshman)" 
		replace fresh_soph = "soph" if na == "(sophomore)"

	drop if _m == 2
	drop _m na
	
*** RACE ***
	
	destring race, replace 

	assert (race >= 0 & race <= 6) if race!=.
		* if this returns an error, there are values of race in the raw Student
		* files without any corresponding values in VCCS provided codebook

	
*** RACE DUMMIES ***

	*recoding with 0/1

	global racedummies r_amind_alsk r_asian r_black r_hawpac r_hisp r_nspec r_white hisp_fl

		foreach race of global racedummies {
			assert `race' == "Y" | `race' == "N" | `race' == ""
			replace `race' = "1" if `race' == "Y"
			replace `race' = "0" if `race' == "N"
		}
		
	destring r_*, replace
	
	
*** NEW_RACE ***
	
	destring new_race, replace 
	assert new_race >= 0 & new_race <=8
		* if this returns an error, there are values of new_race in the raw Student
		* files without any corresponding values in VCCS provided codebook		

	
*** STATUS ***

	assert status=="1" | status=="2" | status=="3"
		* if this returns an error, there are values of status
		* not accounted for above

	
*** STRM ***
	
	replace strm=substr(year,1,1)+substr(year,3,2)+"2" if term=="3_spe" & strm==""
	replace strm=substr(year,1,1)+substr(year,3,2)+"3" if term=="4_sue" & strm==""
	replace strm=substr(year,1,1)+substr(year,3,2)+"4" if term=="6_fae" & strm==""
	
	assert strm!="." & strm!=""
		* if this returns an error, the code above did not properly fill strm.

	
*** TUITION_EXCEPTION ***
 
	merge m:1 tuition_exception using "$built_crosswalks/tuition_exception_codebook", ///
		keepusing(tuition_exception tuition_exception_text)

	*replacing the tuition_exception_text with tuition_exception if no codebook info
	replace tuition_exception_text=tuition_exception if tuition_exception_text=="" & tuition_exception!=""
	 
	drop if _m == 2
	drop _m 
 
 
*** ZIP ***
													
	* This variable holds a normal US 5-digit zip code:
	gen zip_us = substr(zip,1,5)
	
	replace zip_us = "." if !regexm(zip_us, "[0-9][0-9][0-9][0-9][0-9]")

	
	*** Filling in zip codes for campuses 
	*** Using zips from specific campuses (using home_campus variable) when available
	*** If home_campus is missing, then use main/largest campus.
	gen collzip = ""
		replace collzip="24486" if college=="Blue Ridge" 
		replace collzip="24502" if college=="Central Virginia" 
		replace collzip="24422" if college=="Dabney S. Lancaster" 
		replace collzip="24541" if college=="Danville" 
		replace collzip="23410" if college=="Eastern Shore"  
		replace collzip="22408" if college=="Germanna" & home_campus=="FAC"
		replace collzip="22408" if college=="Germanna" & home_campus==""
		replace collzip="22408" if college=="Germanna" & home_campus=="OFF"
		replace collzip="22508" if college=="Germanna" & home_campus=="LGC"
		replace collzip="23228" if college=="J. Sargeant Reynolds" 
		replace collzip="23831" if college=="John Tyler" & home_campus=="CHSTR"
		replace collzip="23831" if college=="John Tyler" & home_campus==""
		replace collzip="23114" if college=="John Tyler" & home_campus=="MIDLO"
		replace collzip="22645" if college=="Lord Fairfax" & home_campus=="MIDD"
		replace collzip="22645" if college=="Lord Fairfax" & home_campus==""
		replace collzip="20187" if college=="Lord Fairfax" & home_campus=="FAUQ"
		replace collzip="24219" if college=="Mountain Empire" 
		replace collzip="24084" if college=="New River" 
		replace collzip="22311" if college=="Northern Virginia" & home_campus=="A"
		replace collzip="22003" if college=="Northern Virginia" & home_campus=="N"
		replace collzip="22003" if college=="Northern Virginia" & home_campus==""
		replace collzip="20164" if college=="Northern Virginia" & home_campus=="L"
		replace collzip="20109" if college=="Northern Virginia" & home_campus=="M"
		replace collzip="22191" if college=="Northern Virginia" & home_campus=="W"
		replace collzip="22150" if college=="Northern Virginia" & home_campus=="H"
		replace collzip="24112" if college=="Patrick Henry" 
		replace collzip="23851" if college=="Paul D. Camp" & home_campus=="FRKLN"
		replace collzip="23851" if college=="Paul D. Camp" & home_campus==""
		replace collzip="23434" if college=="Paul D. Camp" & home_campus=="SUFFK"
		replace collzip="22902" if college=="Piedmont Virginia" 
		replace collzip="23149" if college=="Rappahannock" & home_campus=="GLENN"
		replace collzip="23149" if college=="Rappahannock" & home_campus==""
		replace collzip="22572" if college=="Rappahannock" & home_campus=="WARSW"
		replace collzip="23821" if college=="Southside Virginia" & home_campus=="CHR"
		replace collzip="23947" if college=="Southside Virginia" & home_campus=="DAN"
		replace collzip="23947" if college=="Southside Virginia" & home_campus==""
		replace collzip="24609" if college=="Southwest Virginia" 
		replace collzip="23666" if college=="Thomas Nelson" & home_campus=="MAIN"
		replace collzip="23666" if college=="Thomas Nelson" & home_campus==""
		replace collzip="23188" if college=="Thomas Nelson" & home_campus=="HT"
		replace collzip="23322" if college=="Tidewater" & home_campus=="C"
		replace collzip="23510" if college=="Tidewater" & home_campus=="N"
		replace collzip="23701" if college=="Tidewater" & home_campus=="P"
		replace collzip="23453" if college=="Tidewater" & home_campus=="B"
		replace collzip="23453" if college=="Tidewater" & home_campus==""
		replace collzip="24210" if college=="Virginia Highlands" 
		replace collzip="24015" if college=="Virginia Western" 
		replace collzip="24382" if college=="Wytheville" 
	assert collzip!=""
	
	* Preparing zip variables for merge with zip code data
	rename zip_us zip1
	rename collzip zip2
	merge n:1 zip1 zip2 using "$built_crosswalks/distance to VA zips up to 500 miles.dta", ///
		keep(master match) gen(zip_merge)
		
	* _merge = 1 for students in the same zip code as college.
	* replacing distance = 0 for these students
	replace mi_to_zcta5 = 0 if zip1==zip2
	replace zip_merge=3 if zip1==zip2
	
	* Missing zips = "00000"
	gen missingzip=zip1=="00000"
	tab strm missingzip
		// zips fully missing Spring 2008 and before
	
	* Valid zip1s are more than 500 miles away
	* Top-coding at 500 miles
	replace mi_to_zcta5 = 500 if zip_merge==1 & ///
		missingzip==0 & real(strm) >= 2083
	
	* renaming/dropping variables 
	rename mi_to_zcta5 distance_stud_to_coll
	rename zip1 zip_us
	rename zip2 collzip
	drop zip_merge missingzip 
	

*** CREATING NEW VARIABLE FOR FIRST TERM ENROLLED

	destring strm, replace
	egen firstterm = min(strm), by(vccsid)
	

*** CREATING NEW VARIABLE FOR ONLY DUAL ENROLLMENT
	
	gen dual_enrollment = 	curr=="04A" | curr=="041" | curr=="042" | ///
							curr=="043" | xdul=="Y"
							
	egen only_de = min(dual_enrollment), by(vccsid)
	
	
*** Trimming all string variables ***
	foreach var of varlist _all {
		disp "`var'"
		capture nois replace `var'=trim(`var')
		}

	
*** ADDING LABELS ***

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
		sheet(variable_labels_student) raw(old_name) clean(new_name) label(label) keepx namelabel

	global value_label_vars "citz_status fhe mhe race new_race status"
	
	foreach var of global value_label_vars {
	
		encodefrom `var' using "$codebook/master_use_variable_labels.xlsx", ///
		filetype(excel) sheet(`var') raw(raw) clean(clean) label(label) allow_missing
		
	}	
	
*** FINAL ASSERT CHECKS *** 

	assert (mhe >= 0 & mhe <= 7) if mhe!=.
		* if this returns an error, there is a new value of fhe
		* which has not been accounted for above	
	assert (fhe >= 0 & fhe <= 7) if fhe!=.
		* if this returns an error, there is a new value of fhe
		* which has not been accounted for above	

*** ORDERING & DESTRINGING ***

	order year term vccsid acadplan* age ceeb* citz_status college ///
		college_last_attended collnum collnum_location ctg curr* cip dayeve ///
		ferpa fhe fp_code ftic gender hisp_fl home_campus hs_grad_year hsgpa ///
		institution juris juris_text juris_instate mhe mil_status mil_status_text new_race ///
		ovcountry parent_campus_a campus prev_degree prev_degree_text ///
		program_level intended_degree intended_degreetype fresh_soph ps_juris ///
		qtr_head_code quarter_code r_* race residency status strm ///
		total_credit_hrs tuition_exception tuition_exception_text ///
		tuition_residency visa xdul zip zip_us

	
	** Destring all relevant variables
	
	global destring_vars "year age collnum ctg cip hsgpa juris_instate program_level total_credit_hrs strm admit_term" 
	
	foreach var of global destring_vars {
		
		destring `var' , replace
		
		}

	
*** SAVING *** 	
	local year=substr("`file'",2,4)
	local term=substr("`file'",7,5)
	drop file
		
	sort vccsid collnum
	zipsave "$build_data/$filetype/${filetype}_`year'_`term'", replace		
	
	}
	

