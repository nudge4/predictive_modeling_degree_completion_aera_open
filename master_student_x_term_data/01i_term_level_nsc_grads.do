*************************************************
*** TERM-LEVEL DATA FROM NSC FILES -- DEGREES ***
*************************************************

/*

This .do file uses the NSC build files to create a long panel 
of student x term level data that tracks degree attainment
at non-VCCS institutions.

The resulting dataset $working_data/term_level_grads_nsc.dta contains the  
following student x term level information: 

	(1) Whether the student earned a non-VCCS credential during that term
	(2) The type of institution from which the student earned
			a non-VCCS credential during that term
	(3) The degree level earned during that term

Because academic terms are not consistent across colleges, the NSC data
does not include term indicators, and instead includes graduation dates.  
We create term indicators: 

	* Graduated in a Spring term if their graduation date was 
		between January 1st and June 30th

	* Graduated in a Summer term if their graduation date was 
		between July 1st and August 31st
		
	* Graduated in a Fall term if their graduation date was 
		between September 1st and December 31st. 

Note that the dataset contains information for only one credential per term.
The credential described is the one with the highest level, with 
Graduate > Bachelor > Associate > Certificate > Diploma > Unknown.  

This can be easily changed by omitting the line: 
	keep vccsid strm degree_level_nonvccs1 ${college_type1}
	
Unlike the NSC enrollment files, the indicators in #2 are mutually exclusive
	within each student x term observation.

*/ 

zipuse "$build_files/NSC/NSC_graduation_all_records.dta.zip", clear

*** Removing all records for VCCS Graduations
*** UPDATE 4/1/20: changing to separately identifying VCCS degrees
*** for the needs of vccsid_covid_response project
/*
drop if state=="VA" & two_four==2 & type=="Public" & ///
	college!="Richard Bland College" 
*/
gen vccs = state=="VA" & two_four==2 & type=="Public" & ///
	college!="Richard Bland College"
	
		
*** Dropping unnecessary variables
drop coll_seq degree_title fice major college
rename deg_cip_1 deg_cip
duplicates drop 
		
*** Assigning graduation term based on grad_date

	** Min and Max year present in the data
	gen year=year(grad_date)
	sum year
	local minyear=r(min)
	local maxyear=r(max)

	** strm = graduation term based on date ranges below
	gen strm = . 
	gen acadyr = ""
	forvalues year=`minyear'/`maxyear' {
		* Spring graduations
		replace strm = real("2"+substr("`year'",3,2)+"2") if ///
			grad_date >= td(01jan`year') & ///
			grad_date < td(01jul`year')
			
		* Summer graduations
		replace strm = real("2"+substr("`year'",3,2)+"3") if ///
			grad_date >= td(01jul`year') & ///
			grad_date < td(01sep`year')
			
		* Fall graduations
		replace strm = real("2"+substr("`year'",3,2)+"4") if ///
			grad_date >= td(01sep`year') & ///
			grad_date <= td(31dec`year')
			
		* Filling in acad_yr to merge in College Scorecard data
		local yearplus = `year'+1
		local yearminus = `year'-1
		replace acadyr = "`yearminus'_`year'" if year==`year' & ///
			substr(string(strm),4,1)=="2" 
		replace acadyr = "`year'_`yearplus'" if year==`year' & ///
			substr(string(strm),4,1)=="3"
		replace acadyr = "`year'_`yearplus'" if year==`year' & ///
			substr(string(strm),4,1)=="4"
			
		}
		drop grad_date year	
		
		* Converting acadyr to College Scorecard version
		replace acadyr = substr(acadyr,1,5)+substr(acadyr,8,2)
		replace acadyr = "$most_recent_scorecard" if ///
			real(substr(acadyr,1,4)) > real(substr("$most_recent_scorecard",1,4))
		
*** Degree type	(consistent with VCCS degree types)
	gen degree_level_nonvccs = ""
		replace degree_level_nonvccs = "Diploma" 	if credential_level_code=="PD"
		replace degree_level_nonvccs ="Certificate" if credential_level_code=="UC"
		replace degree_level_nonvccs = "Associate" 	if credential_level_code=="AD"
		replace degree_level_nonvccs = "Bachelor" 	if credential_level_code=="BD"
		replace degree_level_nonvccs = "Graduate" 	if credential_level_code=="DP" | ///
			credential_level_code=="DR" | credential_level_code=="MD" | ///
			credential_level_code=="PC" 
		replace degree_level_nonvccs = "Unknown" 	if credential_level_code=="" | ///
			credential_level_code=="CR"
	drop credential_level*
	
	** Creating student-level dataset that includes when the student
	** earned which type of degree -- includes all degrees earned at non-VCCS,
	** not just highest level 
	preserve
		* Indicator for earning each type of degree
		* (max) in collapse
		gen deg_nonvccs_graduate = degree_level_nonvccs=="Graduate"
		gen deg_nonvccs_bachelor = degree_level_nonvccs=="Bachelor"
		gen deg_nonvccs_associate = degree_level_nonvccs=="Associate"
		gen deg_nonvccs_certificate = degree_level_nonvccs=="Certificate"
		gen deg_nonvccs_diploma = degree_level_nonvccs=="Diploma"
		gen deg_nonvccs_unknown = degree_level_nonvccs=="Unknown" 
		
		* first term earned that type of degree 
		* (min) in collapse
		foreach type in graduate bachelor associate certificate diploma unknown {
			gen deg_nonvccs_`type'_strm = strm if deg_nonvccs_`type'==1 
			}
			
		* collapse globals
		global collapse_min ""
		global collapse_max ""
		foreach type in graduate bachelor associate certificate diploma unknown {
			global collapse_max "$collapse_max deg_nonvccs_`type'"
			global collapse_min "$collapse_min deg_nonvccs_`type'_strm"
			}
			
		* collapsing to student level
		collapse (max) $collapse_max (min) $collapse_min, by(vccsid)
		
		* saving as separate file
		sort vccsid
		zipsave "$working_data/student_level_nonvccs_degree_type_strm", replace
	restore
		
*** College type

	** Merging in College Scorecard data 
	* n:1 merge
	sort ipeds acadyr
	zipmerge ipeds acadyr using ///
		"$working_data/college_scorecard_2000_01_to_${most_recent_scorecard}"
		drop if _merge==2
		rename _merge merge_sc_`year'
	
	** Type of College attended = sector, level (IPEDS), in/out of state (NSC)
	** If doesn't match to IPEDS (~1% of obs), then using type/two_four from
	** NSC data.  Based on colleges that don't match to IPEDS, classifying all
	** schools with type = "Private" as for-profit
	global college_type ""

		* Public 4-year, instate
		gen grad_pub4yr_instate = control==1 & ///
			iclevel==1 & state=="VA" 
		replace grad_pub4yr_instate = 1 if control==. & ///
			type=="Public" & two_four==4 & state=="VA"
		global college_type "$college_type grad_pub4yr_instate"
		
		* Public 2-year, instate
		gen grad_pub2yr_instate = control==1 & ///
			(iclevel==2 | iclevel==3) & state=="VA" 
		replace grad_pub2yr_instate = 1 if control==. & ///
			type=="Public" & two_four<4 & state=="VA"
		global college_type "$college_type grad_pub2yr_instate"
		
		* Non-profit private 4-year, instate
		gen grad_nfp4yr_instate = control==2 & ///
			iclevel==1 & state=="VA" 
		global college_type "$college_type grad_nfp4yr_instate"
		
		* Non-profit prviate 2-year, instate
		gen grad_nfp2yr_instate = control==2 & ///
			(iclevel==2 | iclevel==3) & state=="VA" 
		global college_type "$college_type grad_nfp2yr_instate"
			
		* For-profit private 4-year, instate
		gen grad_fp4yr_instate = control==3 & ///
			iclevel==1 & state=="VA" 
		replace grad_fp4yr_instate = 1 if control==. & ///
			type=="Private" & two_four==4 & state=="VA"
		global college_type "$college_type grad_fp4yr_instate"
		
		* For-profit prviate 2-year, instate
		gen grad_fp2yr_instate = control==3 & ///
			(iclevel==2 | iclevel==3) & state=="VA" 
		replace grad_fp2yr_instate = 1 if control==. & ///
			type=="Private" & two_four < 4 & state=="VA"
		global college_type "$college_type grad_fp2yr_instate"			
		
		* Public 4-year, out of state
		gen grad_pub4yr_outstate = control==1 & ///
			iclevel==1 & state!="VA" 
		replace grad_pub4yr_outstate = 1 if control==. & ///
			type=="Public" & two_four==4 & state!="VA"
		global college_type "$college_type grad_pub4yr_outstate"
		
		* Public 2-year, out of state
		gen grad_pub2yr_outstate = control==1 & ///
			(iclevel==2 | iclevel==3) & state!="VA" 
		replace grad_pub2yr_outstate = 1 if control==. & ///
			type=="Public" & two_four<4 & state!="VA"
		global college_type "$college_type grad_pub2yr_outstate"
		
		* Non-profit private 4-year, out of state
		gen grad_nfp4yr_outstate = control==2 & ///
			iclevel==1 & state!="VA" 
		global college_type "$college_type grad_nfp4yr_outstate"
		
		* Non-profit prviate 2-year, out of state
		gen grad_nfp2yr_outstate = control==2 & ///
			(iclevel==2 | iclevel==3) & state!="VA" 
		global college_type "$college_type grad_nfp2yr_outstate"
			
		* For-profit private 4-year, out of state
		gen grad_fp4yr_outstate = control==3 & ///
			iclevel==1 & state!="VA" 
		replace grad_fp4yr_outstate = 1 if control==. & ///
			type=="Private" & two_four==4 & state!="VA"
		global college_type "$college_type grad_fp4yr_outstate"
		
		* For-profit prviate 2-year, out of state
		gen grad_fp2yr_outstate = control==3 & ///
			(iclevel==2 | iclevel==3) & state!="VA" 
		replace grad_fp2yr_outstate = 1 if control==. & ///
			type=="Private" & two_four<4 & state!="VA"
		global college_type "$college_type grad_fp2yr_outstate"	

		gen degree_college_type = "" 
		foreach type of global college_type {
			replace degree_college_type = substr("`type'",6,.) if `type'==1
			replace degree_college_type = "" if vccs==1
			}
	drop two_four state type iclevel control 
	
	** Creating separate grad_* variables for quality variables
	global quality_vars "c150_4 c150_l4 satvr25 satvr75 satmt25 satmt75 actcm25 actcm75 md_earn_wne_p10 adm_rate cdr3"
	global grad_quality_vars ""
	foreach var of global quality_vars  {
		rename `var' grad_`var'
		global grad_quality_vars "$grad_quality_vars grad_`var'"
		replace grad_`var' = . if vccs==1
		}
	
	
*** Reshaping to student x term level
	duplicates drop 
	
	** Creating sortable list so that, within a term, degree1 is the highest
	gen degree_level_num = .
		replace degree_level_num = 1 if degree_level_nonvccs=="Graduate"
		replace degree_level_num = 2 if degree_level_nonvccs=="Bachelor" 
		replace degree_level_num = 3 if degree_level_nonvccs=="Associate" 
		replace degree_level_num = 4 if degree_level_nonvccs=="Certificate"
		replace degree_level_num = 5 if degree_level_nonvccs=="Diploma" 
		replace degree_level_num = 6 if degree_level_nonvccs=="Unknown"
	assert degree_level_num!=.

	** Reshaping to student x term level
	set seed 1 
	gen random = runiform()
	gen missingcip = deg_cip==""
	gsort vccsid strm degree_level_num -missingcip random
	bys vccsid strm: gen n=_n
	drop degree_level_num ipeds random opeid merge_sc missingcip
	reshape wide degree_level_nonvccs ${college_type} ${grad_quality_vars} ///
		degree_college_type deg_cip full_fice vccs, ///
		i(vccsid strm) j(n)
		
	** How many student x term obs earn multiple degrees in one term?
	** Multiple degrees from multiple types of colleges? 
	count
	count if degree_college_type2!=""
		// 8% have multiple degrees in one term 
	count if degree_college_type1!=degree_college_type2 & degree_college_type2!=""
		// 8% of those who earn multiple degrees in one term 
		// earn from different college types
		
	count if full_fice2!=""
	count if full_fice1!=full_fice2 & full_fice2!=""
		//10% of those who earn multiple degrees in one term 
		// earn from different college types
		
	count if degree_level_nonvccs2!=""
	count if degree_level_nonvccs1!=degree_level_nonvccs2 & degree_level_nonvccs2!=""
	tab degree_level_nonvccs2
		// 80% of second degrees are degree level "Unknown" -- most of these
		// appear to be students with double majors 		
	
	** For now, only keeping top degree earned in each term
	global college_type1 ""
	foreach var of global college_type {
		global college_type1 "$college_type1 `var'1"
		}
	global grad_quality_vars1 ""
	foreach var of global grad_quality_vars {
		global grad_quality_vars1 "$grad_quality_vars1 `var'1"
		}
	
	keep vccsid strm degree_level_nonvccs1 deg_cip1 vccs1 ///
		${college_type1} ${grad_quality_vars1}
	
	rename deg_cip1 deg_cip_nonvccs
	rename degree_level_nonvccs1 degree_level_nonvccs 
	rename vccs1 vccs
	foreach var of global college_type {
		rename `var'1 `var'
		}	
	foreach var of global grad_quality_vars {
		rename `var'1 `var'
		}
	
*** Indicator that student graduated from non-VCCS during this term		
	gen grad_nonvccs=1 if vccs==0
	
*** Indicator that the student graduates from VCCS during this term,
*** according to NSC data.  Also having VCCS-specific degree level 
*** and CIP, and removing information about VCCS degrees from 
*** non-VCCS versions of those variables
	rename vccs grad_vccs_nsc
	gen degree_level_vccs_nsc = degree_level_nonvccs if grad_vccs_nsc==1
	gen degree_cip_vccs_nsc = deg_cip_nonvccs if grad_vccs_nsc==1
	replace degree_level_nonvccs = "" if grad_vccs_nsc==1
	replace deg_cip_nonvccs = "" if grad_vccs_nsc==1
	
*** Replacing grad_nonvccs = 0 if grad_vccs_nsc = 1, and vice versa
	replace grad_nonvccs = 0 if grad_nonvccs==. & grad_vccs_nsc==1
	replace grad_vccs_nsc = 0 if grad_vccs_nsc==. & grad_nonvccs==1
	assert grad_nonvccs!=.
	assert grad_vccs_nsc!=.	
	
*** Removing any vccsids not present in Student files
	// n:1 merge
	sort vccsid
	zipmerge vccsid using "$working_data/unique_vccsid_student_files"
		drop if _merge!=3
		drop _merge	
	
*** Saving student x term level data
	isid vccsid strm
	sort vccsid strm
	order vccsid strm grad_nonvccs ${college_type} degree_level_nonvccs
	zipsave "$working_data/term_level_grads_nsc", replace

	
		
