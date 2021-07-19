/******************************************************************************* 
							NSC MASTER USE FILES						
*******************************************************************************/

/*

This file reads in `all_raw_records_NSC’, which was created in 
data_appending.do. It also reads in the codebook information from the 
tempfiles `var_codebook’ created in build_all_crosswalks.do.  It cleans data, 
ensuring variables are in the same format across years, edits any inconsistencies
and merges in information from the VCCS codebook for the variable mentioned above. 

This script ultimately saves nsc_enrollment_records and nsc_graduation_records, 
which contains all data we have from VCCS thusfar, and year files for each year we have. 
*/


***** ENROLLMENT RECORDS *****

if `nsc_enrollment_switch' == 1 {


*** Appending all relevant years of NSC enrollment data
clear
local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
local filelist: list sort filelist
display `filelist'
set obs 1
gen n = 1
foreach file of local filelist {

	disp "`file'"
	
	if "`file'" != "all_recs_w_vccs_NA_deid.dta.zip"  {

		zipappend using "$raw_data/$filetype/dta files/`file'"

	}
	}
	drop if n==1
	drop n
	
		
*** dropping graduation variables
	drop grad_date degree major deg_cip_1 grad 
	
*** dropping superfluous variables 
	assert s_date == "20040601"
	assert chk_return=="10"
	drop s_date chk_return

	
*** Checking for non-missing vccsids for all observations	
	assert !missing(vccsid) & vccsid != "."

*** CIP 
	
	replace enrol_cip_1 = "" if enrol_cip_1 == "NA"
	replace enrol_cip_2 = "" if enrol_cip_2 == "NA"
	
	replace enrol_cip_1 = substr("000000", 1, 6 - length(enrol_cip_1)) + enrol_cip_1 if length(enrol_cip_1) <= 6 ///
		& !missing(enrol_cip_1)	

	replace enrol_cip_2 = substr("000000", 1, 6 - length(enrol_cip_2)) + enrol_cip_2 if length(enrol_cip_2) <= 6 ///
		& !missing(enrol_cip_2)		
	
*** DATE VARS 

	local date_vars = "enrol_begin enrol_end"
	
	foreach var of local date_vars	{
	
		generate `var'_td = date(`var', "YMD")
		format `var'_td %td 
		drop `var' 
		rename `var'_td `var'
	}	
	

*** MERGING IN CROSSWALK FOR IPEDS ID

	* Importing excel version of this crosswalk
	preserve
		import excel using "$codebook/NSC_SCHOOL_CODE_TO_IPEDS_UNIT_ID_XWALK.xlsx", ///
			sheet(LU_SCPROFIL_TO_IPEDS_UNITID) firstrow clear
			
		rename NSC_COLLEGE_AND_BRANCH full_fice
		rename IPEDS ipeds
			
		* Rows with non-missing IPEDS are uniquely identified
		* by collegecode_branchcode and ipeds
		keep full_fice ipeds
		
		tempfile nsc_ipeds_crosswalk
		save `nsc_ipeds_crosswalk', replace
	restore
	
	merge n:1 full_fice using `nsc_ipeds_crosswalk', keep(master match)
		
		* Number of colleges without an ipeds code
		tab college if _merge==1
		drop _merge
			// currently 25 colleges (or separate campuses within system)
			// only 355 student x term observations affected, out of 
			// more than 13 million

	
*** Additional data checks 
	
	assert length(fice) == 6
	assert length(full_fice) == 9
		* if this returns an error, you may need to add leading zeros to the FICE. 
		
		** the "assert"s below will result in an error if you have strange values
		** of enrol_begin or enrol_end (three values of enrol_begin are in the 90s, 
		** on value of enrol_end is in 2021)
	assert (year(enrol_begin) > 1990 & year(enrol_begin) <= 2022) | missing(enrol_begin) 
	assert (year(enrol_end) > 2000 & year(enrol_end) <= 2022) | missing(enrol_end)	
		
*** DESTRINGING 

	local destring_vars = "coll_seq first_enrol"
	
	foreach var of local destring_vars {
	
		destring `var', replace
		
	}	
	
*** ADDING VARIABLE LABELS ***

	global label_vars = "two_four enrol_status"
	
	foreach var of global label_vars {
	
		encodefrom `var' using "$codebook/master_use_variable_labels.xlsx", ///
		filetype(excel) sheet(`var') raw(raw) clean(clean) label(label) allow_missing
	
	}

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
	sheet(variable_labels_NSC_enrollment) raw(old_name) clean(new_name) label(label) keepx namelabel

		* putting vccsid first 
	order vccsid 	
	
*** SAVING ***

	** saving each individual year x term file
	tab file
	local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
	local filelist: list sort filelist
	disp `filelist'
	replace file = file+".dta.zip"	

	foreach file of local filelist {
	
		if "`file'" != "all_recs_w_vccs_NA_deid.dta.zip" {
		
		preserve
			disp "`file'"
			keep if file=="`file'"
			local year=substr("`file'",17,4)
			drop file
				
			sort vccsid enrol_begin enrol_end
			zipsave "$build_data/$filetype/${filetype}_enrollment_`year'", replace		
		restore
		}
	}


}

***** GRADUATION RECORDS *****

if `nsc_grad_switch' == 1 {


zipuse "$raw_data/$filetype/dta files/all_recs_w_vccs_NA_deid.dta.zip", clear 

*** Dropping enrollment vars 

	drop enrol_begin enrol_end enrol_status enrol_maj_1 enrol_cip_1 enrol_cip_2 ///
		enrol_maj_2 first_enrol file grad 
		
*** dropping superfluous variables 
	assert s_date == "20040601"
	assert chk_return=="10"
	drop s_date chk_return
	
	assert !missing(vccsid) & vccsid != "."
		
*** CIP 

	replace deg_cip_1 = "" if deg_cip_1 == "NA" 
		* fixing one incorrect CIP - checked this with the NSC CIP lookup
	replace deg_cip_1 = "150702" if deg_cip_1 == "QAS"
	replace deg_cip_1 = "513801" if deg_cip_1 == "51.38."
	replace deg_cip_1 = "513901" if deg_cip_1 == "51.39."
	
	replace deg_cip_1 = substr("000000", 1, 6 - length(deg_cip_1)) + deg_cip_1 if length(deg_cip_1) <= 6 ///
		& !missing(deg_cip_1)
	

*** DEGREE TITLE

	merge m:1 degree using "$built_crosswalks/credential_crosswalk", ///
		keep(master match) 
		tab _merge
		drop _merge
		// 89.42% _m == 3 
	
*** GRAD_DATE 

	generate grad_date_td = date(grad_date, "YMD")
	format grad_date_td %td
	drop grad_date 
	rename grad_date_td grad_date 
	
	
*** MERGING IN CROSSWALK FOR IPEDS ID

	* Importing excel version of this crosswalk
	preserve
		import excel using "$codebook/NSC_SCHOOL_CODE_TO_IPEDS_UNIT_ID_XWALK.xlsx", ///
			sheet(LU_SCPROFIL_TO_IPEDS_UNITID) firstrow clear
			
		rename NSC_COLLEGE_AND_BRANCH full_fice
		rename IPEDS ipeds
			
		* Rows with non-missing IPEDS are uniquely identified
		* by collegecode_branchcode and ipeds
		keep full_fice ipeds
		
		tempfile nsc_ipeds_crosswalk
		save `nsc_ipeds_crosswalk', replace
	restore
	
	merge n:1 full_fice using `nsc_ipeds_crosswalk', keep(master match)
		
		* Number of colleges without an ipeds code
		tab college if _merge==1
		drop _merge
	
*** Additional assert checks 

	assert length(fice) == 6
	assert length(full_fice) == 9
		* if this returns an error, you may need to add leading zeros to the FICE. 
		
		** the "assert" below will result in an error if you have strange values
		** of grad_date
	assert (year(grad_date) > 2003 & year(grad_date) <=2020) | missing(grad_date) 	


*** DESTRINGING 

	local destring_vars = "coll_seq"
	
	foreach var of local destring_vars {
	
		destring `var', replace
		
	}	
	
*** ADDING VARIABLE LABELS ***

	global label_vars = "two_four"
	
	foreach var of global label_vars {
	
		encodefrom `var' using "$codebook/master_use_variable_labels.xlsx", ///
		filetype(excel) sheet(`var') raw(raw) clean(clean) label(label) allow_missing
	
	}

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
	sheet(variable_labels_NSC_grad) raw(old_name) clean(new_name) label(label) keepx namelabel			
	
		* putting vccsid first 
	order vccsid 
	
*** SAVING 

	sort vccsid grad_date
	zipsave "$build_data/$filetype/${filetype}_graduation_all_records", replace	
	
	
}		
		
		
	/* 
	***Filling in degree_level for unclassified observations
	replace degree_level = "ADDT" if degree_title=="ADDITIONAL MAJOR" 
	replace degree_level = "ADDT" if degree_title=="ADDITIONAL MAJOR PROGRAM" 
	replace degree_level = "ADDT" if degree_title=="ADDTNL/MGT" 
	replace degree_level = "ADDT" if degree_title=="ADDTNL/MKT" 
	replace degree_level = "ADDT" if degree_title=="ADDTNL/PA" 
	replace degree_level = "ADDT" if degree_title=="CONCENTRATION GRADUATE" 
	replace degree_level = "ADDT" if degree_title=="CONCENTRATION UNDERGRADUATE" 
	replace degree_level = "ADDT" if degree_title=="CONC/FIN" 
	replace degree_level = "ADDT" if degree_title=="CONC/GHINF" 
	replace degree_level = "ADDT" if degree_title=="CONC/MGT" 
	
	replace degree_level = "GRAD" if degree_title=="ADULT NURSE PRACTITIONER"
 	replace degree_level = "ASSC" if degree_title=="AGS:GENERAL STUDIES" 
	replace degree_level = "ASSC" if strpos(degree_title,"AS ")==1 
	replace degree_level = "ASSC" if degree_title=="AS:SCIENCE" 
	replace degree_level = "ASSC" if degree_title=="ASSOC DEGREE INFO:" 
	replace degree_level = "ASSC" if strpos(degree_title=="ASSOCIATE IN")==1 
	replace degree_level = "BACH" if degree_title=="B M" 
	replace degree_level = "BACH" if strpos(degree_title,"B.S. ")==1 
	replace degree_level = "BACH" if strpos(degree_title,"B.A. ")==1 
	replace degree_level = "BACH" if strpos(degree_title,"B. S. ")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BA-")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BACAHELOR")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BA/")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BACH DEGREE")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BACH OF")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BACHELOR")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BAHELOR")==1 
	replace degree_level = "BACH" if degree_title==="BCJ" 
	replace degree_level = "BACH" if strpos(degree_title,"BS IN ")==1 
	replace degree_level = "CERT" if strpos(degree_title,"CERT ")==1 
	replace degree_level = "CERT" if strpos(degree_title,"CERTIFICATE ")==1 
	replace degree_level = "BACH" if strpos(degree_title,"B.S. ")==1 

		
		
		
		
	

if `nsc_grad_switch' == 1 {


use "$raw_data/$filetype/dta files/all_recs_w_vccs_NA_deid.dta", clear 

*** Dropping enrollment vars 

	drop enrol_begin enrol_end enrol_status enrol_maj_1 enrol_cip_1 enrol_cip_2 ///
		enrol_maj_2 first_enrol file grad 
		
*** dropping superfluous variables 
	assert s_date == "20040601"
	assert chk_return=="10"
	drop s_date chk_return
	
	assert !missing(vccsid) & vccsid != "."
		
*** CIP 

	replace deg_cip_1 = "" if deg_cip_1 == "NA" 
		* fixing one incorrect CIP - checked this with the NSC CIP lookup
	replace deg_cip_1 = "150702" if deg_cip_1 == "QAS"
	replace deg_cip_1 = "513801" if deg_cip_1 == "51.38."
	replace deg_cip_1 = "513901" if deg_cip_1 == "51.39."
	
	replace deg_cip_1 = substr("000000", 1, 6 - length(deg_cip_1)) + deg_cip_1 if length(deg_cip_1) <= 6 ///
		& !missing(deg_cip_1)
	

*** DEGREE TITLE

	merge m:1 degree using "$built_crosswalks/credential_crosswalk", ///
		keep(master match) 
		tab _merge
		drop _merge
		// 89.42% _m == 3 
	
*** GRAD_DATE 

	generate grad_date_td = date(grad_date, "YMD")
	format grad_date_td %td
	drop grad_date 
	rename grad_date_td grad_date 
	
	
*** MERGING IN CROSSWALK FOR IPEDS ID

	* Importing excel version of this crosswalk
	preserve
		import excel using "$codebook/NSC_SCHOOL_CODE_TO_IPEDS_UNIT_ID_XWALK.xlsx", ///
			sheet(LU_SCPROFIL_TO_IPEDS_UNITID) firstrow clear
			
		rename NSC_COLLEGE_AND_BRANCH full_fice
		rename IPEDS ipeds
			
		* Rows with non-missing IPEDS are uniquely identified
		* by collegecode_branchcode and ipeds
		keep full_fice ipeds
		
		tempfile nsc_ipeds_crosswalk
		save `nsc_ipeds_crosswalk', replace
	restore
	
	merge n:1 full_fice using `nsc_ipeds_crosswalk', keep(master match)
		
		* Number of colleges without an ipeds code
		tab college if _merge==1
		drop _merge
	
*** Additional assert checks 

	assert length(fice) == 6
	assert length(full_fice) == 9
		* if this returns an error, you may need to add leading zeros to the FICE. 
		
		** the "assert" below will result in an error if you have strange values
		** of grad_date
	assert (year(grad_date) > 2003 & year(grad_date) <=2019) | missing(grad_date) 	


*** DESTRINGING 

	local destring_vars = "coll_seq"
	
	foreach var of local destring_vars {
	
		destring `var', replace
		
	}	
	
*** ADDING VARIABLE LABELS ***

	global label_vars = "two_four"
	
	foreach var of global label_vars {
	
		encodefrom `var' using "$codebook/master_use_variable_labels.xlsx", ///
		filetype(excel) sheet(`var') raw(raw) clean(clean) label(label) allow_missing
	
	}

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
	sheet(variable_labels_NSC_grad) raw(old_name) clean(new_name) label(label) keepx namelabel			
	
		* putting vccsid first 
	order vccsid 
	
*** SAVING 

	save "$build_data/$filetype/${filetype}_graduation_all_records.dta", replace	
	
	
}		
		
		
	/* 
	***Filling in degree_level for unclassified observations
	replace degree_level = "ADDT" if degree_title=="ADDITIONAL MAJOR" 
	replace degree_level = "ADDT" if degree_title=="ADDITIONAL MAJOR PROGRAM" 
	replace degree_level = "ADDT" if degree_title=="ADDTNL/MGT" 
	replace degree_level = "ADDT" if degree_title=="ADDTNL/MKT" 
	replace degree_level = "ADDT" if degree_title=="ADDTNL/PA" 
	replace degree_level = "ADDT" if degree_title=="CONCENTRATION GRADUATE" 
	replace degree_level = "ADDT" if degree_title=="CONCENTRATION UNDERGRADUATE" 
	replace degree_level = "ADDT" if degree_title=="CONC/FIN" 
	replace degree_level = "ADDT" if degree_title=="CONC/GHINF" 
	replace degree_level = "ADDT" if degree_title=="CONC/MGT" 
	
	replace degree_level = "GRAD" if degree_title=="ADULT NURSE PRACTITIONER"
 	replace degree_level = "ASSC" if degree_title=="AGS:GENERAL STUDIES" 
	replace degree_level = "ASSC" if strpos(degree_title,"AS ")==1 
	replace degree_level = "ASSC" if degree_title=="AS:SCIENCE" 
	replace degree_level = "ASSC" if degree_title=="ASSOC DEGREE INFO:" 
	replace degree_level = "ASSC" if strpos(degree_title=="ASSOCIATE IN")==1 
	replace degree_level = "BACH" if degree_title=="B M" 
	replace degree_level = "BACH" if strpos(degree_title,"B.S. ")==1 
	replace degree_level = "BACH" if strpos(degree_title,"B.A. ")==1 
	replace degree_level = "BACH" if strpos(degree_title,"B. S. ")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BA-")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BACAHELOR")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BA/")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BACH DEGREE")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BACH OF")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BACHELOR")==1 
	replace degree_level = "BACH" if strpos(degree_title,"BAHELOR")==1 
	replace degree_level = "BACH" if degree_title==="BCJ" 
	replace degree_level = "BACH" if strpos(degree_title,"BS IN ")==1 
	replace degree_level = "CERT" if strpos(degree_title,"CERT ")==1 
	replace degree_level = "CERT" if strpos(degree_title,"CERTIFICATE ")==1 
	replace degree_level = "BACH" if strpos(degree_title,"B.S. ")==1 

		
		
		
		
	
