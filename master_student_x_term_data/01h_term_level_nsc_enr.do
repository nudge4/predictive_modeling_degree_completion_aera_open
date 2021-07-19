***************************************************
*** TERM-LEVEL DATA FROM NSC FILES - ENROLLMENT ***
***************************************************

/*

This .do file uses the NSC build files to create a long panel 
of student x term level data that tracks enrollment at non-VCCS institutions.

The resulting dataset $working_data/term_level_nsc_enr.dta contains the  
following student x term level information: 

	(1) Whether the student enrolled in any non-VCCS institution in that term
	(2) The type of institution(s) the student enrolled at in that term

Because academic terms are not consistent across colleges, the NSC data
does not include term indicators, and instead includes enrollment beginning
and enrollment ending dates for each record.  We create term indicators: 

	* Enrolled in a Spring term if their enrollment begin date was between 
		January 1st and April 30th AND their enrollment end date was between 
		January 1st and May 31st
		
	* Enrolled in a Summer term if their enrollment begin date was between 
		May 1st and July 31st AND their enrollment end date was between 
		June 1st and August 31st
		
	* Enrolled in a Fall term if their enrollment begin date was between 
		August 1st and December 31st AND their enrollment end date was between 
		September 1st and December 31st. 
		
Because students may have enrolled in multiple colleges during one term, 
the indicators in #2 are not mutually exclusive.
		
This definition means that a student may be labeled as enrolled in two or 
more terms based on a single NSC enrollment record.  For example, if a
NSC record shows enrollment between November 1st, 2016 and February 1st, 2017,
then that student will be labeled as enrolled in both Fall 2016 and Spring 2017
based on that record.  This strategy ensures that all NSC enrollment records
correspond to at least one term.

*/ 

global nsc_enr_using "vccsid college full_fice ipeds enrol_status state type two_four enrol_begin enrol_end" 


*** Compiling all NSC enrollment terms
clear
local filelist: dir "$build_files/NSC" files "*.dta.zip"
local filelist: list sort filelist

foreach file of local filelist {
if 	"`file'" != "NSC_graduation_all_records.dta.zip" & ///
	"`file'" != "NSC_enrollment_1992.dta.zip" & ///
	"`file'" != "NSC_enrollment_1995.dta.zip" & ///
	"`file'" != "NSC_enrollment_2002.dta.zip" & ///
	"`file'" != "NSC_enrollment_2003.dta.zip" {

preserve
	
	zipuse "$build_files/NSC/`file'", clear
	keep ${nsc_enr_using}
	gen file = "`file'" 
	local year = real(substr(file,16,4))
	disp "`year'"
	local yearplus = `year'+1
	gen acadyr = ""
	
	* removing all records for VCCS enrollment
	drop if state=="VA" & two_four==2 & type=="Public" & ///
		college!="Richard Bland College" 
			
	* Converting NSC records to Spring, Summer, and Fall terms
	forvalues yr = `year'/`yearplus' {

		local strm = real("2" + substr(string(`yr'),3,2))
		disp "`strm'"
		
		* For populating acadyr variables
		local yrminus = `yr'-1
		local yrplus = `yr'+1
		
		* Spring terms
		gen enrolled`strm'2 = enrol_begin >= td(01jan`yr') & enrol_begin < td(01may`yr')
		replace enrolled`strm'2 = 1 if enrol_end >= td(01jan`yr') & enrol_end < td(01jun`yr')
		replace acadyr="`yrminus'_`yr'" if enrolled`strm'2==1
		
		* Summer terms
		gen enrolled`strm'3 = enrol_begin >= td(01may`yr') & enrol_begin < td(01aug`yr') 
		replace enrolled`strm'3 = 1 if enrol_end >= td(01jun`yr') & enrol_end < td(01sep`yr')
		replace acadyr="`yr'_`yrplus'" if enrolled`strm'3==1
		
		* Fall terms
		gen enrolled`strm'4 = enrol_begin >= td(01aug`yr') & enrol_begin <= td(31dec`yr')
		replace enrolled`strm'4 = 1 if enrol_end >= td(01sep`yr') & enrol_end < td(31dec`yr')
		replace acadyr="`yr'_`yrplus'" if enrolled`strm'4==1
					
		}
					
	egen terms = rowtotal(enrolled*)
	assert terms!=0 
		// all rows must correspond to at least one term
	tab terms
	
	
	*** Merging in data from College Scorecard
	
		* First, making acadyr variable compatible with College Scorecard data
		replace acadyr = substr(acadyr,1,5)+substr(acadyr,8,2)
		
		* Replacing acadyr with most recently available 
		replace acadyr = "$most_recent_scorecard" if ///
			real(substr(acadyr,1,4)) > real(substr("$most_recent_scorecard",1,4))
			
		* Merging using ipeds x acadyr
		* n:1 merge
		sort ipeds acadyr
		zipmerge ipeds acadyr using ///
			"$working_data/college_scorecard_2000_01_to_${most_recent_scorecard}"
			drop if _merge==2
			rename _merge merge_sc_`year'
			
	
	** Creating term-specific information for the type/quality of 
	** college(s) attended in that term.
	forvalues yr = `year'/`yearplus' {
	forvalues term = 2/4 {
					
		local strm = real("2" + substr(string(`yr'),3,2) + "`term'")
		disp "`strm'"
		
		*** Type of college attended: sector, level from IPEDS, state from NSC
		** If college doesn't match to IPEDS (~1% of obs), then using type/two_four from
		** NSC data.  Based on colleges that don't match to IPEDS, classifying all
		** schools with type = "Private" as for-profit			
		global college_type ""

			* Public 4-year, instate
			gen enr_pub4yr_instate`strm' = control==1 & ///
				iclevel==1 & state=="VA" & enrolled`strm'==1
			replace enr_pub4yr_instate`strm' = 1 if control==. & ///
				type=="Public" & two_four==4 & state=="VA"
			global college_type "$college_type enr_pub4yr_instate"
			
			* Public 2-year, instate
			gen enr_pub2yr_instate`strm' = control==1 & ///
				(iclevel==2 | iclevel==3) & state=="VA" & ///
				enrolled`strm'==1
			replace enr_pub2yr_instate`strm' = 1 if control==. & ///
				type=="Public" & two_four==2 & state=="VA"					
			global college_type "$college_type enr_pub2yr_instate"

			* Non-profit private 4-year, instate
			gen enr_nfp4yr_instate`strm' = control==2 & ///
				iclevel==1 & state=="VA" & enrolled`strm'==1
			global college_type "$college_type enr_nfp4yr_instate"

			* Non-profit private 2-year, instate
			gen enr_nfp2yr_instate`strm' = control==2 & ///
				(iclevel==2 | iclevel==3) & state=="VA" & ///
				enrolled`strm'==1
			global college_type "$college_type enr_nfp2yr_instate"
				
			* For-profit private 4-year, instate
			gen enr_fp4yr_instate`strm' = control==3 & ///
				iclevel==1 & state=="VA" & enrolled`strm'==1
			replace enr_fp4yr_instate`strm' = 1 if control==. & ///
				type=="Private" & two_four==4 & state=="VA"
			global college_type "$college_type enr_fp4yr_instate"
				
			* For-profit private 2-year, instate
			gen enr_fp2yr_instate`strm' = control==3 & ///
				(iclevel==2 | iclevel==3) & state=="VA" & ///
				enrolled`strm'==1
			replace enr_fp2yr_instate`strm' = 1 if control==. & ///
				type=="Private" & two_four<4 & state=="VA"
			global college_type "$college_type enr_fp2yr_instate"
				
			* Public 4-year, out of state				
			gen enr_pub4yr_outstate`strm' = control==1 & ///
				iclevel==1 & state!="VA" & enrolled`strm'==1
			replace enr_pub4yr_outstate`strm' = 1 if control==. & ///
				type=="Public" & two_four==4 & state!="VA"
			global college_type "$college_type enr_pub4yr_outstate"

			* Public 2-year, out of state
			gen enr_pub2yr_outstate`strm' = control==1 & ///
				(iclevel==2 | iclevel==3) & state!="VA" & enrolled`strm'==1
			replace enr_pub2yr_outstate`strm' = 1 if control==. & ///
				type=="Public" & two_four<4 & state!="VA"
			global college_type "$college_type enr_pub2yr_outstate"

			* Non-profit private 4-year, out of state
			gen enr_nfp4yr_outstate`strm' = control==2 & ///
				iclevel==1 & state!="VA" & enrolled`strm'==1
			global college_type "$college_type enr_nfp4yr_outstate"

			* Non-profit private 2-year, out of state
			gen enr_nfp2yr_outstate`strm' = control==2 & ///
				(iclevel==2 | iclevel==3) & state!="VA" & enrolled`strm'==1
			global college_type "$college_type enr_nfp2yr_outstate"

			* For-profit private 4-year, out of state
			gen enr_fp4yr_outstate`strm' = control==3 & ///
				iclevel==1 & state!="VA" & enrolled`strm'==1
			replace enr_fp4yr_outstate`strm' = 1 if control==. & ///
				type=="Private" & two_four==4 & state!="VA"
			global college_type "$college_type enr_fp4yr_outstate"

			* For-profit private 2-year, out of state
			gen enr_fp2yr_outstate`strm' = control==3 & ///
				(iclevel==2 | iclevel==3) & state!="VA" & enrolled`strm'==1
			replace enr_fp2yr_outstate`strm' = 1 if control==. & ///
				type=="Private" & two_four<4 & state!="VA"
			global college_type "$college_type enr_fp2yr_outstate"
			
				
		*** Quality of institution 
		
			* High value = higher quality
			global high_value_quality "c150_4 c150_l4 satvr25 satvr75 satmt25 satmt75 actcm25 actcm75 md_earn_wne_p10"
			foreach var of global high_value_quality {
				gen enr_`var'`strm' = `var' if enrolled`strm'==1
				}	
			
			* Low value = higher quality 
			global low_value_quality "adm_rate cdr3"
			foreach var of global low_value_quality {
				gen enr_`var'`strm' = `var' if enrolled`strm'==1
				}
				
			* Adding enr_ prefix to quality variables
			global quality_vars ""
			foreach level in high low {
			foreach var of global `level'_value_quality {
				global quality_vars "$quality_vars enr_`var'"
				}
				}
		}
		}
	
	*** Collapsing data from student x college x term => student
	
		* For each enrollment type created above, using (max) so that these
		* are not mutually exclusive within student x term cell in case
		* a student attended multiple colleges that term.
		global college_type_star = ""
		foreach var of global college_type {
			global college_type_star "$college_type_star `var'*"
			}
			
		* For institutional quality measures, using (max) or (min) so that 
		* the information for the highest quality college is recorded
		global max_quality_star ""
		foreach var of global high_value_quality {
			drop `var'
			global max_quality_star "$max_quality_star enr_`var'*"
			}
		global min_quality_star ""
		foreach var of global low_value_quality {
			drop `var'
			global min_quality_star "$min_quality_star enr_`var'*"
			}

		* Collapsing
		collapse (max) enrolled* ${college_type_star} ${max_quality_star} ///
				(min) ${min_quality_star} ///
			,  by(vccsid)
	
	*** Reshaping from student => student x term
	reshape long enrolled $college_type $quality_vars ///
		, i(vccsid) j(strm)
	
	tempfile terms_all_students
	save `terms_all_students'
	
restore

* Appending all year-level files 
	append using `terms_all_students'
	
}
}
	
*** Collapsing data once more, because terms duplicated across years
*** Final dataset structure: student x college
	collapse (max) enrolled $college_type $quality_vars, ///
		by(vccsid strm)
	
	** Dropping observations not associated with enrollment
	drop if enrolled==0
	
*** Indicator for any non-VCCS enrollment
	rename enrolled enr_nonvccs
	
*** Removing any vccsids not present in Student files
	// n:1 merge
	sort vccsid
	zipmerge vccsid using "$working_data/unique_vccsid_student_files"
		drop if _merge!=3
		drop _merge
	

*** Saving
	isid vccsid strm
	sort vccsid strm
	order vccsid strm enr_nonvccs ${college_type}
	zipsave "$working_data/term_level_nsc_enr", replace
	clear all			



