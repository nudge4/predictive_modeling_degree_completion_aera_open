*** Creating sample for analysis and outcomes of interest ***

global user = c(username) 

global box = "/Users/$user/Box Sync"

global gitrepo = "$box/GitHub/predictive_modeling_degree_completion_aera_open"

global working_data = "$box/VCCS restricted student data/Master_student_x_term_data"
	// This dataset constructed using the following do files 
	// 		01*.do (vccs_build_scripts/Master_student_x_term_data)
	//		02_sample_restrictions (some_college_no_degree repo)
	
global project_data = "$box/Predictive Models of College Completion (VCCS)/dta"
	// For storing project data
	

*** Calling student x term level data created as part of SCND work
use "$working_data/all_term_level_restricted.dta", clear

**********************************
*** Making sample restrictions ***
**********************************

*** Sample restrictions already accounted for in $working_data: 
*** 	(1) Excludes students only ever dually enrolled
***		(2) Excludes students who completed a degree (from any institution)
***			prior to their initial term at VCCS.


*** Keeping only students who were enrolled at least one term in 
*** a college-level curriculum
keep if any_abv_collev_nonde==1

*** Keeping students who were first enrolled as non-DE student 
*** between Summer 2007 and Spring 2013, inclusive
keep if first_nonde_strm >= 2073 & first_nonde_strm <=2132
	// Initial term = first_nonde_strm, which is defined as the first term
	// after the student completed all dual enrollment terms at VCCS. 
	
	
*************************************
*** Creating outcomes of interest ***
*************************************

*** Window of observation: 6 years (18 terms) from first_nonde_strm
gen window_obs = term_consec >= first_nonde_term_consec & ///
	term_consec < (first_nonde_term_consec + 18)
	
*** Earned degree within 6 years
*** 	(max) in collapse
gen grad_vccs_6years = grad_vccs if window_obs==1
gen grad_nonvccs_6years = grad_nonvccs if window_obs==1

*** Term earned first degree
***		(min) in collapse
gen first_degree_strm = strm if grad_vccs_6years==1 | grad_nonvccs_6years==1

*** Enrolled at non-VCCS within 6 years
*** 	(max) in collapse
gen enr_nonvccs_6years = enr_nonvccs if window_obs==1

*** First term enrolled at non-VCCS
***		(min) in collapse
gen first_enr_nonvccs_strm = strm if enr_nonvccs_6years==1


*** Last strm within window of observation
gen last_strm = ""
	// Spring 20XX to Fall (20XX+5)
	replace last_strm = "2"+string(real(substr(string(first_nonde_strm),2,2))+5)+"4" ///
		if substr(string(first_nonde_strm),4,1)=="2"
	// Summer 20XX to Spring (20XX+6)
	replace last_strm = "2"+string(real(substr(string(first_nonde_strm),2,2))+6)+"2" ///
		if substr(string(first_nonde_strm),4,1)=="3"	
	// Fall 20XX to Summer (20XX+6)
	replace last_strm = "2"+string(real(substr(string(first_nonde_strm),2,2))+6)+"3" ///
		if substr(string(first_nonde_strm),4,1)=="4"	
	destring last_strm, replace	
	
	
	** How many completed degree after six years? 
	preserve
		gen grad_any = grad_vccs==1 | grad_nonvccs==1
		gen grad_any_6years = grad_any == 1 & window_obs==1
		gen grad_any_after = grad_any == 1 & strm > last_strm
		gen grad_vccs_after = grad_vccs ==1 & strm > last_strm
		gen grad_nonvccs_after = grad_nonvccs==1 & strm > last_strm
		
		collapse (max) grad_any grad_vccs grad_nonvccs ///
			grad_any_after grad_vccs_after grad_nonvccs_after ///
			grad_any_6years grad_vccs_6years grad_nonvccs_6years ///
			, by(vccsid first_nonde_acadyr)
		
		count if grad_any==1 & first_nonde_acadyr == 20072008
		tab grad_any_after grad_any_6years if first_nonde_acadyr == 20072008
		// 5896 / 26113 = 22.5%
		
		count if grad_vccs==1 & first_nonde_acadyr == 20072008
		tab grad_vccs_after grad_vccs_6years if first_nonde_acadyr == 20072008
		// 2479 / 16016 = 15.5%
		
		count if grad_nonvccs==1 & first_nonde_acadyr == 20072008
		tab grad_nonvccs_after grad_nonvccs_6years if first_nonde_acadyr == 20072008
		// 6727 / 16790 = 40.1%
	restore
	
*** Collapsing to student-level
collapse (max) grad_vccs_6years grad_nonvccs_6years enr_nonvccs_6years ///
		(min) first_degree_strm first_enr_nonvccs_strm ///
	, by(vccsid first_nonde_* last_strm)

*** Merging in student-level data on all degree levels earned
	zipmerge 1:1 vccsid using "$working_data/student_level_vccs_degree_type_strm.dta"
		drop if _merge==2
		foreach type in associate certificate diploma {
			* Filling in zeros for students not present in VCCS graduation data
			replace deg_vccs_`type' = 0 if _merge==1
			
			* Not including degrees earned outside 6 years 
			replace deg_vccs_`type' = 0 if ///
				deg_vccs_`type'_strm > last_strm & ///
				deg_vccs_`type'_strm!=. 
			replace deg_vccs_`type'_strm = . if ///
			deg_vccs_`type'_strm > last_strm
			
			* Checking degree timing 
			assert deg_vccs_`type'_strm >= first_nonde_strm & ///
				deg_vccs_`type'_strm <= last_strm if ///
				deg_vccs_`type'==1
			}
		drop _merge
		
	
	zipmerge 1:1 vccsid using "$working_data/student_level_nonvccs_degree_type_strm.dta"
		drop if _merge==2
		foreach type in graduate bachelor associate certificate diploma unknown {
			* Filling in zeros for students not present in nonVCCS graduation data
			replace deg_nonvccs_`type' = 0 if _merge==1
			
			* Not including degrees earned outside 6 years 
			replace deg_nonvccs_`type' = 0 if ///
				deg_nonvccs_`type'_strm > last_strm & ///
				deg_nonvccs_`type'_strm!=. 
			replace deg_nonvccs_`type'_strm = . if ///
				deg_nonvccs_`type'_strm > last_strm & ///
				deg_nonvccs_`type'_strm!=. 
				
			* Checking degree timing 
			assert deg_nonvccs_`type'_strm >= first_nonde_strm & ///
				deg_nonvccs_`type'_strm <= last_strm if ///
				deg_nonvccs_`type'==1
			}
		drop _merge


*** Saving data
	isid vccsid 
	save "$project_data/student_level_sample_and_outcomes.dta", replace

	
	
