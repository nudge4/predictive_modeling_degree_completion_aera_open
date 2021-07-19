/******************************************************************************* 
					CODEBOOK INFO FOR MASTER BUILD FILES					
*******************************************************************************/

/* 

This do file reads in raw codebook files in .csv format from the 
$codebook location, as specified in the master script.  This do file
then completes any data cleaning necessary in order to merge with 
the raw files within the `filetype'_build_master_use.do files, in order
to either label existing variables or create new variables. 

This do files saves all crosswalks as .dta files in the $Crosswalks
location, as specified in the master script, to facilitate ease
of use in the other build scripts. 

*/


clear all
set more off

************************ READING IN INFO FROM CODEBOOK *************************
************************ AND OTHER RELEVANT CROSSSWALKS ************************


*** ACADPLAN ***
	* NOTE: this is an updated crosswalk we received directly from VCCS
	* in January 2019 in the form of a SAS format file. Simple modifications
	* (e.g. text-to-columns) were required to get the information into a 
	* usable excel format.
	import excel using "$codebook/acadplannames_edited.xlsx", firstrow clear
	
	* the college code "261" refers to the VCCS system office 
	drop if strpos(collnum_acadplan , "261") == 1

	* removing any spaces from collnum_acadplan
	replace collnum_acadplan = subinstr(collnum_acadplan," ","",.)
	drop if collnum_acadplan == ""

	* Renaming fields and selecting which to keep
	rename eff_date acadplan_eff_date
	rename description acadplan_description
	rename diploma_description acadplan_dipl_descr
	rename trnscr_descr acadplan_transcript_descr

	* Cutting down to make it a crosswalk
	keep collnum_acadplan acadplan_eff_date acadplan_description ///
		acadplan_dipl_descr acadplan_transcript_descr
		* merge in using collnum_acadplan -- this contains all of the acadplans 
		* from VCCS, even the ones that we don't observe in the student data yet, 
		* just in case we see them later.
	
	* Merging in curriculum value
	gen acadplan = substr(collnum_acadplan,5,.)
	gen curr=""
	gen length = length(acadplan)
	replace curr = substr(acadplan,1,3) if length <= 6
	replace curr = substr(acadplan,5,3) if length > 6
	drop length	
		
		
	* Creating degree level based on acadplan
	gen acadplan_deglvl = ""
		* Transfer-oriented associate degrees
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Associate of Arts & Science")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Associates of Arts & Science")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Associate in Arts")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Associate in Science")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Associate of Science")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Associate of Arts")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_description,"AA&S")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"AA&S Degree")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_description,"AS-")==1
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_description,"AA-")==1
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Liberal Arts")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Associate of  Science Degree")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"A.A.S.")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_dipl_desc,"Associate of Fine Arts")!=0
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_description,"Arts and Sciences")==1
		replace acadplan_deglvl = "AA&S" if strpos(acadplan_description,"AFA")==1
		replace acadplan_deglvl = "AA&S" if curr=="836" 
		replace acadplan_deglvl = "AA&S" if curr=="831"
		replace acadplan_deglvl = "AA&S" if curr=="699" | curr == "697"
		replace acadplan_deglvl = "AA&S" if curr=="647"
		replace acadplan_deglvl = "AA&S" if curr=="624"
		replace acadplan_deglvl = "AA&S" if curr=="233"
		
		* applied associate degrees
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"Associate in Applied Science")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"Associate of Applied Science")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_description,"AAS")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"AAS Degree")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"AAS  Degree")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"Associates of Applied Science")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_description,"AAA-")==1
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"Associate in Applied Arts")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"Associate of Applied Arts")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"Associate Applied Science")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"Associate of  Applied Science")!=0
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"AAS")==1
		replace acadplan_deglvl = "AAS" if strpos(acadplan_dipl_desc,"Associiate of Applied Science")!=0
		replace acadplan_deglvl = "AAS" if curr=="718"
		replace acadplan_deglvl = "AAS" if curr=="299"
		replace acadplan_deglvl = "AAS" if curr=="298"
		replace acadplan_deglvl = "AAS" if curr=="294"
		replace acadplan_deglvl = "AAS" if curr=="251"
		replace acadplan_deglvl = "AAS" if curr=="212"
		replace acadplan_deglvl = "AAS" if curr=="172"
		replace acadplan_deglvl = "AAS" if curr=="156"
		replace acadplan_deglvl = "AAS" if curr=="146"
		replace acadplan_deglvl = "AAS" if curr=="118"
		replace acadplan_deglvl = "AAS" if curr=="109"
	
		* Certificate
		replace acadplan_deglvl = "CERT" if strpos(acadplan_dipl_desc,"Certificate")!=0
		replace acadplan_deglvl = "CERT" if strpos(acadplan_description,"CERT")!=0
		replace acadplan_deglvl = "CERT" if curr=="190"
		replace acadplan_deglvl = "CERT" if curr=="159"
		replace acadplan_deglvl = "CERT" if curr=="158"
		replace acadplan_deglvl = "CERT" if curr=="157"
		replace acadplan_deglvl = "CERT" if curr=="089"
		
		* Career studies certificate
		replace acadplan_deglvl = "CSC" if strpos(acadplan_dipl_desc,"CSC")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_dipl_desc,"Certificate in Cs:")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_transcript_descr,"CSC")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_description,"CSC")!=0
		replace acadplan_deglvl = "CSC" if strpos(collnum_acadplan,"_221-")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_dipl_desc,"Career Studies")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_description,"Career Studies")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_transcript_descr,"Career Studies")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_description,"CS Certificate")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_description,"CS Cert")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_description,"Cs Cert")!=0
		replace acadplan_deglvl = "CSC" if strpos(acadplan_description,"CS")==1
		replace acadplan_deglvl = "CSC" if strpos(acadplan_transcript_descr,"Cs:")==1
		replace acadplan_deglvl = "CSC" if curr=="069"
		
		* Diplomas
		replace acadplan_deglvl = "DIPL" if strpos(acadplan_dipl_desc,"Diploma")!=0
		replace acadplan_deglvl = "DIPL" if curr=="996"
		
		* Non-degree program
		replace acadplan_deglvl = "N/A" if strpos(acadplan_description,"Unclassified")!=0
		replace acadplan_deglvl = "N/A" if strpos(acadplan_description,"Unknown")!=0
		replace acadplan_deglvl = "N/A" if strpos(acadplan_description,"High School")!=0
		replace acadplan_deglvl = "N/A" if strpos(acadplan_description,"Personal Sat")!=0
		replace acadplan_deglvl = "N/A" if strpos(acadplan_description,"Special Consideration")!=0
		replace acadplan_deglvl = "N/A" if strpos(acadplan_description,"Dummy")!=0
		replace acadplan_deglvl = "N/A" if acadplan_description=="General Education"
		replace acadplan_deglvl = "N/A" if acadplan_description=="Special Curriculum"
		replace acadplan_deglvl = "N/A" if acadplan_description=="Special History Curriculum"
		replace acadplan_deglvl = "N/A" if acadplan_description=="Upgrade Skills"
		replace acadplan_deglvl = "N/A" if acadplan_description=="Upgrading Emp Skills"
		replace acadplan_deglvl = "N/A" if acadplan_description=="Develope Job Skills"
		
		* Pre-admission programs
		replace acadplan_deglvl = "PRE" if strpos(collnum_acadplan,"PRE")!=0
		replace acadplan_deglvl = "PRE" if strpos(acadplan_description,"Pre-Admit")!=0
		replace acadplan_deglvl = "PRE" if strpos(acadplan_transcript_desc,"Pre-Admission")!=0
		replace acadplan_deglvl = "PRE" if strpos(acadplan_description,"Pending")==1		
		replace acadplan_deglvl = "PRE" if strpos(acadplan_description,"Pre-")==1		
		replace acadplan_deglvl = "PRE" if strpos(acadplan_description,"Pre-Admission")!=0
	
		* Unknown programs
		replace acadplan_deglvl = "UNK" if acadplan_deglvl==""

		
	* Trimming leading/lagging spaces from string variables
	foreach var of varlist _all {
		capture replace `var' = trim(`var')
		}
		
	save "$built_crosswalks/acadplan_crosswalk.dta", replace	

	
*** CEEB ***	
	** importing crosswalk from UNC
	import excel "$codebook/ncessch_ceeb_crosswalk_master_current.xlsx", ///
		clear firstrow case(lower)
	keep hs_name hs_address hs_city hs_state hs_ceeb ncessch state_schid hs_zip
		
		* Cleaning up variables
		gen pubpriv = "Public"
		rename hs_name 		schoolname
		rename hs_address 	address
		rename hs_city 		city
		rename hs_state		state
		rename ncessch		ncessch
		rename state_schid	state_schid
		rename hs_zip		zip 
		rename hs_ceeb		ceeb
		replace ceeb = substr("000000", 1, 6 - length(ceeb)) + ceeb if length(ceeb) <= 6 

	tempfile unc_ceeb
	save `unc_ceeb', replace
	
	** importing last institution data sent by Marina at VCCS 
	import excel "$codebook/Copy of LSTINST_from_SCHEV.xlsx", ///
			clear firstrow case(lower)
		
		* Cleaning up variables
		rename lstinst ceeb
		rename lstinst_text schoolname
		replace ceeb = substr("000000", 1, 6 - length(ceeb)) + ceeb if length(ceeb) <= 6 
		drop c 

	tempfile schev_ceeb
	save `schev_ceeb', replace
	
	
	
	* importing SAS ceeb crosswalk from VCCS - only VA schools *
	import excel "$codebook/ceeb.xlsx", ///
		clear firstrow case(lower)
		* note that all of these ceeb codes are from the state of VA. 
		
		* Cleaning up variables
		rename j 			id
		rename county 		county
		rename schoolname 	schoolname
		rename address 		address
		rename city 		city
		rename state 		state
		rename zip 			zip
		rename pubpriv 		pubpriv

		tostring ceeb, replace 
		replace ceeb = substr("000000", 1, 6 - length(ceeb)) + ceeb if length(ceeb) <= 6 
		replace pubpriv = "" if pubpriv == " "

		drop collnum id 

	tempfile vccs_ceeb
	save `vccs_ceeb', replace


	** Merging VCCS SAS crosswalk with UNC crosswalk found online
	merge 1:1 ceeb using `unc_ceeb', update
		drop _merge

	** Mering VCCS SAS + UNC crosswalk with SCHEV crosswalk from Marina to see if 
	** there is any additional info
	merge 1:1 ceeb using `schev_ceeb', update
		drop _merge

	isid ceeb

	* Cleaning up var names 
	rename county ceeb_county 
	rename schoolname ceeb_schoolname
	rename address ceeb_address
	rename city ceeb_city 
	rename state ceeb_state
	rename pubpriv ceeb_pubpriv
	rename ncessch ceeb_ncessch
	rename state_schid ceeb_state_schid

	* Trimming leading/lagging spaces from string variables
	foreach var of varlist _all {
		capture replace `var' = trim(`var')
		}
		
	save "$built_crosswalks/ceeb_crosswalk", replace	
	
	
*** COLLNUM
	import excel using "$data_dictionary", sheet("collnum") cellrange(A20:B43) firstrow clear
	tostring collnum, replace

	replace collnum_text = "Southside Virginia" if collnum_text == "Southside"
	replace collnum_text = "Piedmont Virginia" if collnum_text == "Piedmont"
	replace collnum_text = "Southwest Virginia" if collnum_text == "Southwest" 

	save "$built_crosswalks/collnum_names_codebook", replace 
	

*** COMPONENT 
	import excel using "$data_dictionary", sheet("component") cellrange(A20:B33) firstrow clear
	rename compnt component
	rename compnt_text component_text

	save "$built_crosswalks/component_codebook", replace 
	

*** COURSE TITLES
	local filelist: dir "$box/VCCS restricted student data/Raw/Course" files "*.csv"
	local filelist: list sort filelist
	clear
	foreach file of local filelist {
		preserve
			import delimited using "$box/VCCS restricted student data/Raw/Course/`file'", ///
				stringcols(_all) clear
			keep collnum psclass_num pscourse_num strm course_title
			
			tempfile course_title
			save `course_title', replace
		restore
	append using `course_title'
	}
	duplicates drop

	* Courses prior to Spring 2005 do not have psclass_num/pscourse_num assigned
	* in the Course files.  Dropping these from the crosswalk
	drop if real(strm) < 2052
	
	* ensuring courses are uniquely identified 
	isid collnum psclass_num pscourse_num strm

	save "$built_crosswalks/course_title_crosswalk", replace
	
	
	
*** CPI *** 

	* pulling in from Fed CPI data (https://fred.stlouisfed.org/series/CPALTT01USQ661S), 
	* updated as of March 2020
	import delimited "$codebook/CPI_build_files_${cpi_adjust}.csv", clear
	rename cpaltt01usq661s cpi

	* creating a year by quarter indicator 	
	gen year = substr(date, 3, 2)
		* dropping quarters before the start of the employment data
		drop if year < "05"
		drop if year >= "60"
	replace year = "20" + year
	destring year, replace

	* creating quarter variable, which is equal to 1 through 4
	sort date
	bysort year: gen qtr = _n

	* creating year x quarter variable
	gen cpi_quarter = string(year) + "q" + string(qtr)
	gen cpi_quarter_tq = quarterly(cpi_quarter, "YQ")

	drop cpi_quarter
	rename cpi_quarter_tq cpi_quarter

	format cpi_quarter %tq
	keep cpi_quarter cpi
				
	* saving CPI from the reference in a local to be used in adjustment equation 
	* global $cpi_adjust is defined in the employment_build_master_use.do file
	* and is typically most recent quarter of CPI data available
	* As of March 2020, this is 2019q4
	local cpi_adjust_tq = quarterly("$cpi_adjust", "YQ")
	dis `cpi_adjust_tq'
	gen id = _n if cpi_quarter == `cpi_adjust_tq'
	sum id
	local idcheck = `r(min)'
	local cpi_reference = cpi[`idcheck']
	dis `cpi_reference'
	drop id

	save "$built_crosswalks/cpi_crosswalk", replace	
	
	

*** CURR ***
	* NOTE: this is an updated crosswalk we received directly from VCCS
	* in January 2019 in the form of a SAS format file. Simple modifications
	* (e.g. text-to-columns) were required to get the information into a 
	* usable excel format.
	import excel using "$codebook/curr_edited.xlsx", firstrow clear
	
	* cleaning up variables
	replace curr = subinstr(curr,"'","",.)
	replace curr = subinstr(curr," ","",.)
	replace degree = subinstr(degree,"'","",.)
	rename desc curr_text
	rename degree curr_degree 	
	
	* adding a row for a value that doesn't exist here 
	* but does exist in the "Data Dictionary II" codebook
	local new = _N + 1
	set obs `new'
	replace curr = "192" 					if curr == ""
	replace curr_text = "Physical Fitness" 	if curr == "192"
	replace curr_degree = "DIPL" 			if curr == "192"
	replace cip = 51.1601 					if curr == "192"	
	
	* Trimming leading/lagging spaces from string variables
	foreach var of varlist _all {
		capture replace `var' = trim(`var')
		}
		
	* Setting CIP value to missing for all non-degree programs
	replace cip = . if curr_degree=="N/A"
	assert substr(curr,1,1)=="0" if cip==.
		
	save "$built_crosswalks/curr_crosswalk", replace
	

*** CIP *** 
	* NOTE: we downloaded the CIPCode2020 from IES's website: 
	* https://nces.ed.gov/ipeds/cipcode/resources.aspx?y=56 
	* 	(see "CIPCode 2020" under Resources => Download heading)
	* Most recently downloaded on May 22nd, 2020 by Kelli Bird	
	import delimited using "$codebook/CIPCode2020.csv", varnames(1) clear
	
	* Saving 2-digit CIP information
	preserve
		keep if cipfamily==cipcode
		bysort cipcode: gen n = _n 
		keep if n == 1
		
		rename cipcode cip2 
		rename ciptitle cip2title
		keep cip2*
		
		save "$built_crosswalks/cip2_title", replace
	restore
	
	* Saving Full CIP information (will be 6-digit for most programs)
	drop if cipfamily == cipcode
	drop if strpos(cipdefinition,"Instructional content for this group")!=0
	isid cipcode
	
	rename cipcode cip
	keep cip cipdefinition ciptitle
	gen cip_string = string(cip)
	drop cip
	rename cip_string cip
	save "$built_crosswalks/fullcip_title_description", replace		
	
	
*** GRADE
	import excel using "$data_dictionary", sheet("grade") cellrange(A20:B35) firstrow clear
	replace grade = "" if grade == "<blank>"
	replace grade = trim(grade)
	replace grade_text = trim(grade_text)
	replace grade_text = "" if grade_text == "?????"

	save "$built_crosswalks/grade_codebook", replace 	
	
	
*** INSTMOD 
	import excel using "$data_dictionary", sheet("instmod") cellrange(A20:B41) firstrow clear

	save "$built_crosswalks/instmod_codebook", replace 

	
*** JURIS INFO ***
	insheet using "$codebook/juris.csv", clear names

	save "$built_crosswalks/juris_codebook", replace
	
*** NAICS *** 

	* LINK TO SOURCE: https://www.census.gov/eos/www/naics/downloadables/downloadables.html, 
	* UPDATED AS OF February 2019
	import excel using "$codebook/NAICS crosswalks/2017_NAICS_Descriptions.xlsx", firstrow case(lower) clear 

	drop description 
	rename code naics 

	replace title = trim(title)
	replace title = substr(title,1,length(title)-1) if substr(title,-1,1) == "T"


	* fixing these ones which had a "range" in the crosswalk
	* to allow for complete merging of two digit NAICS
	local new = _N + 1
	set obs `new'
	replace naics = "32" if naics == ""
	replace title = "Manufacturing" if naics == "32"

	local new = _N + 1
	set obs `new'
	replace naics = "33" if naics == ""
	replace title = "Manufacturing" if naics == "33"

	replace naics = "31" if naics == "31-33"

	local new = _N + 1
	set obs `new'
	replace naics = "45" if naics == ""
	replace title = "Retail Trade" if naics == "45"	

	replace naics = "44" if naics == "44-45"

	local new = _N + 1
	set obs `new'
	replace naics = "49" if naics == ""
	replace title = "Transportation and Warehousing" if naics == "49"	

	replace naics = "48" if naics == "48-49" 
	
	
	* creating 2 digit crosswalk 

	preserve 
		keep if length(naics) == 2 
		isid naics 
		rename naics naics_2
		rename title naics_2_title
		
		save "$built_crosswalks/naics_2_crosswalk", replace 
	restore 

	* creating 3 digit crosswalk 

	preserve 
		keep if length(naics) == 3 
		isid naics
		rename naics naics_3
		rename title naics_3_title
		
		save "$built_crosswalks/naics_3_crosswalk", replace  
	restore 

	* creating 4 digit crosswalk 

	preserve 
		keep if length(naics) == 4 
		isid naics
		rename naics naics_4	
		rename title naics_4_title

		save "$built_crosswalks/naics_4_crosswalk", replace 
	restore 

	* creating 5 digit crosswalk 

	preserve 
		keep if length(naics) == 5
		isid naics
		rename naics naics_5
		rename title naics_5_title
		
		save "$built_crosswalks/naics_5_crosswalk", replace 
	restore 

	* creating 6 digit crosswalk 

	preserve 
		keep if length(naics) == 6 
		isid naics
		rename title naics_6_title

		save "$built_crosswalks/naics_6_crosswalk", replace  
	restore 
	
*** NSC Credential-level Crosswalk ***

	** Reading in NSC credential crosswalk
	import excel using "$codebook/CREDENTIAL_LEVEL_LOOKUP_TABLE.xlsx", clear firstrow ///
		sheet("Credential Level Lookup Table") case(lower)
		// updated on August 1st, 2019 by Kelli Bird
		// which is based on degree data submitted to the Clearinghouse 
		// through 6/7/2018
		// link to source: https://nscresearchcenter.org/workingwithourdata/
	
		rename credential_title degree
		
		isid degree
			
		save "$built_crosswalks/credential_crosswalk", replace
	
*** PARENT_CAMPUS_A ***

	import excel using "$data_dictionary", sheet("parent_campus_a") cellrange(A20:H61) firstrow clear
		drop C D F G
		
	gen collnum = substr(collnum_location, 1, 3)
	 
	drop if collegename == "Blue Ridge" & collnum_location == "291_WEYERS CAV"

	replace collegename = "Piedmont Virginia" if collegename == "Piedmont"
	replace collegename = "Southside Virginia" if collegename == "Southside"
	replace collegename = "Southwest Virginia" if collegename == "Southwest"
	replace collegename = "Rappahannock" if collegename == "Rappanhannock"

	rename collegename college 

	save "$built_crosswalks/parent_campus_a_codebook", replace


*** PREV_DEGREE INFO ***

	import excel using "$data_dictionary", sheet("prev_degree") cellrange(A20:B46) firstrow clear
	replace prev_degree = "" if prev_degree == "<blank>"
	replace prev_degree_text = "NA" if prev_degree_text == ""
	
	save "$built_crosswalks/prev_degree_codebook", replace

*** PROGRAM_LEVEL INFO ***

	import excel using "$data_dictionary", sheet("program_level") cellrange(A20:H29) firstrow clear
	drop C D F H
	rename G na
	tostring _all, replace
	replace program_level = trim(program_level)

	save "$built_crosswalks/program_level_codebook", replace

*** TUITION_EXCEPTION INFO ***

	import excel using "$data_dictionary", sheet("tuition_exception") cellrange(A20:B43) firstrow clear
	tostring _all, replace
	replace tuition_exception = trim(tuition_exception)
	replace tuition_exception_text = trim(tuition_exception_text)

	replace tuition_exception = "MILOS" if tuition_exception == "*MILOS*"
	replace tuition_exception_text = "MILOS" if tuition_exception == "MILOS"
	replace tuition_exception = "" if tuition_exception == "<blank>"
	replace tuition_exception_text = "" if tuition_exception_text == "<no response>"

	save "$built_crosswalks/tuition_exception_codebook", replace
	
clear 


	

	

		
