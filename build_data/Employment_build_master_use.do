/******************************************************************************* 
					EMPLOYMENT MASTER USE - BUILD FILE 			
*******************************************************************************/


* Setting any macros
	
	* Pulling CPI value for $cpi_adjust from CPI crosswalk
	* Setting as local to be used below
	use "$built_crosswalks/cpi_crosswalk", clear
	sum cpi if cpi_quarter == tq($cpi_adjust)
	local cpi_reference = r(mean)
	
	
*** Reading in employment quarterly .dta files which are created in ./class_data_appending.do
clear
local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
local filelist: list sort filelist
display `filelist'
foreach file of local filelist {
    di "`file'"
	zipuse "$raw_data/$filetype/dta files/`file'", clear
	
	rename w wage
	rename yr year 
	rename qt qtr 
	
		
*** DROPPING DUPLICATED OBSERVATIONS ***
*** BY STUDENT, EMPLOYER, WAGE *** 	

	duplicates drop vccsid employer_name w, force
	
	
*** FILLING IN ADDRESS VARIABLES FOR DIFFERENCES BEFORE/AFTER 2009 
	capture replace employer_address = employer_st1+" "+employer_st2+" "+employer_city+" "+employer_state+" "+employer_zip ///
			if employer_address==""
	capture replace employer_zip = substr(employer_address,-9,.) ///
			if employer_zip == "" & employer_address==""
	capture replace employer_state = substr(employer_address,-12,2) ///
			if employer_state == "" & employer_address==""
	

** ADJUSTED WAGE ** 

	generate cpi_quarter = year + "q" + qtr
	
	generate cpi_quarter_tq = quarterly(cpi_quarter, "YQ")
	drop cpi_quarter
	rename cpi_quarter_tq cpi_quarter
	format cpi_quarter %tq
	
	merge m:1 cpi_quarter using "$built_crosswalks/cpi_crosswalk", ///
			keep(master match) 
		assert _m == 3
			* if this returns an error, there is a CPI missing for one of the 
			* quarters in the Employment files
	
	destring wage, replace 
	destring year, replace
	
	* Wage adjusted based on CPI local created above
	generate wage_adjusted_$cpi_adjust = (wage * `cpi_reference') / cpi
 
	drop _m
	rename cpi_quarter qtr_tq
		
		
** NAICS ** 
		
	* Setting these values to blank	
	replace naics = "" if naics == "NA" | naics == "0" | naics == "0    0" | naics == "000000"
	
	assert (real(naics) >= 111110 & real(naics) <= 928120) | naics == "" | naics == "999999"
			* if this returns an error, you have a new value of naics which 
			* is outside of the range of naics codes. 
			
	* merging in information on 2 and 6 digit naics codes 
	
	generate naics_2 = substr(naics, 1, 2)
	
	merge m:1 naics_2 using "$built_crosswalks/naics_2_crosswalk", ///
		keep(master match) gen(merge_naics2)
		
	merge m:1 naics using "$built_crosswalks/naics_6_crosswalk", ///
		keep(master match) gen(merge_naics6)
	
	* NAICS codes without match in NAICS crosswalk
	tab naics if merge_naics6==1
	
** Creating any missing variables across years **

	capture generate data_source = ""
	capture generate collnum = ""
	capture generate employer_address = ""
	capture generate employer_city = ""
	capture generate employer_st1 = ""
	capture generate employer_st2 = ""
	capture generate employer_state = ""
	capture generate employer_zip = ""
	capture generate state = ""
	capture generate state_workforce_agency = ""
	capture generate stud_type = ""
	
	
*** CHECKS *** 

	assert vccsid != "" & vccsid != "."
	
				
*** ADDING VARIABLE LABELS ***

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
		sheet(variable_labels_employment) raw(old_name) clean(new_name) label(label) keepx namelabel
				
*** DESTRINGING ***

	foreach var of varlist qtr collnum naics_2 naics_6 {
	
		capture destring `var', replace 
		
	} 
		
*** SAVING INDIVIDUAL QUARTER-LEVEL FILES ***
	
	local year = substr("`file'",2,4)
	local qtr = substr("`file'",7,2)
	
	sort vccsid employer_name
	zipsave "$build_data/$filetype/${filetype}_`year'_`qtr'", replace
	
}



			
	
