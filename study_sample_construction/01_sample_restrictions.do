***********************************
*** OVERALL SAMPLE RESTRICTIONS ***
***********************************

/*

Using the dataset created in the 01a through 01h do files of this repo,
this do file makes additional restrictions:

	(1) Excludes students who were only ever dually enrolled
	(2) Excludes students who earned a degree from any institution prior to 
			their initial (non-DE) VCCS enrollment 
			
This .do file also creates an indicator for whether the student ever enrolled
in a college-level curriculum through regular (not dual) enrollment.  This 
restriction is not applied here, but one can use the any_abv_collev_nonde
to make this restriction for further analysis

The resulting student x term level dataset is $working_data/all_term_level_restricted.dta.

*/


**************
*** MACROS ***
**************

global user = c(username) 
global box "/Users/$user/Box Sync"
global working_data "$box/VCCS restricted student data/Master_student_x_term_data"

zipuse "${working_data}/all_term_level_data", clear
*count
*codebook vccsid


*** Identifying students who were only enrolled at VCCS
*** via Dual Enrollment
	preserve

		* First and last terms of dual and any enrollment
		* First = min in collapse
		* Last = max in collapse
		gen first_de_strm = strm if enr_de==1
		gen last_de_strm = strm if enr_de==1
		gen first_nonde_strm = strm if enr_vccs==1 & enr_de==0
		gen last_nonde_strm = strm if enr_vccs==1 & enr_de==0
	
		* Indicators for dual enrollment
		* Any = max in collapse
		* All = min in collapse
		gen any_de = enr_de 
		gen all_de = enr_de

		collapse 	(max) last_*_strm any_de    ///
					(min) first_*_strm all_de, ///
				by(vccsid) 

		* Number of unique students
		count

		* Students with both DE and regular enrollment who have
		* mismatched terms of enrollment -- enrolled in DE after
		* regular enrollment term
		count if any_de==1 & all_de==0
		count if last_de_strm > first_nonde_strm ///
			& any_de==1 & all_de==0
		count if last_de_strm >= last_nonde_strm ///
			& any_de==1 & all_de==0

		* Reassigning students whose most recent enrollment term is 
		* dual enrollment to "all_de" 
		replace all_de = 1 if last_de_strm >= last_nonde_strm ///
			& any_de==1 & all_de==0
		count if all_de == 1

		* Saving all_de for sample selection
		* Saving any_de and last_de_strm for later use
		keep vccsid any_de all_de last_de_strm
		tempfile student_level_de
		save `student_level_de', replace
	restore
	
	** Merging in indicator for exclusive dual enrollment
		merge n:1 vccsid using `student_level_de'
			assert _merge==3
			drop _merge
			
	** Dropping students who were only enrolled through DE
	disp "DROPPING EXCLUSIVELY DUAL ENROLLMENT STUDENTS"
	drop if all_de == 1
	codebook vccsid 
			

		
	
*** Setting first post-dual enrollment term 
*** must occur after all dual enrollment term
	gen first_nonde_strm_temp = strm if ///
		enr_vccs==1 & enr_de==0 & ///
		(strm > last_de_strm | last_de_strm==.)
	
	egen first_nonde_strm = min(first_nonde_strm_temp), by(vccsid)
	drop first_nonde_strm_temp
	
	* Constructing acadyr variable for all VCCS enrollment terms observable
	gen double acadyr = .
	sum strm if enr_vccs==1,d
	local min_strm = r(min)
	local max_strm = r(max)
	forvalues strm = `min_strm'/`max_strm' {
	
		local term = real(substr(string(`strm'),4,1))
		disp "`term'"
		* Spring terms
		if `term'==2 {
			local year1 = real("20"+substr(string(`strm'),2,2))-1
			local year2 = real("20"+substr(string(`strm'),2,2)) 
			replace acadyr = `year1'`year2' if strm==`strm' & ///
				(enr_vccs==1 | grad_vccs==1)
			}
		
		* Summer and Fall terms
		if `term'==3 | `term'==4 {
			local year1 = real("20"+substr(string(`strm'),2,2))
			local year2 = real("20"+substr(string(`strm'),2,2))+1 
			replace acadyr = `year1'`year2' if strm==`strm' & ///
				(enr_vccs==1 | grad_vccs==1)
			}
		}	
	
	* First non-DE term, in term_consec format
	gen double first_nonde_term_consec_temp = term_consec ///
		if strm == first_nonde_strm
	egen double first_nonde_term_consec = max(first_nonde_term_consec_temp), ///
		by(vccsid)
	drop first_nonde_term_consec_temp
	
	* first non-DE term, in acadyr format
	gen double first_nonde_acadyr_temp = acadyr if strm == first_nonde_strm
	egen double first_nonde_acadyr = max(first_nonde_acadyr_temp), by(vccsid)
	drop first_nonde_acadyr_temp
	
	
	
*** Identifying students who were never enrolled in a college-level curriculum
*** Not to be used for exclusion, but for future analysis as needed
	preserve
	
		* Indicators for above CL enrollment, not part of DE
		* Any term (max) or all terms (min) 
		assert enr_curr!="" if enr_vccs==1
		gen any_abv_collev_nonde = real(enr_curr)>=100 ///
			& enr_de==0 if enr_vccs==1 ///
			& strm >= first_nonde_strm
		gen all_abv_collev_nonde = real(enr_curr)>=100 ///
			& enr_de==0 if enr_vccs==1 ///
			& strm >= first_nonde_strm
		
		collapse 	(max) any_abv_collev_nonde 	///
					(min) all_abv_collev_nonde, ///
				by(vccsid) 
		
		tempfile abv_collev_nonde
		save `abv_collev_nonde', replace
	
	restore
	
	** Merging in below-college-level indicators 
	merge n:1 vccsid using `abv_collev_nonde'
		assert _merge==3
		drop _merge
		
		
		
*** Dropping students who earned non-VCCS degree before enrolling at VCCS
	preserve
	
		* Identifying non-VCCS degrees prior to first non-DE enrollment
		gen nonvccs_deg_b4_vccs= grad_nonvccs == 1 & strm < first_nonde_strm
		
		* Identifying students who earned degree in dual enrollment period
		gen vccs_deg_b4_nonde = grad_vccs == 1 & strm < first_nonde_strm
		
		collapse (max) nonvccs_deg_b4_vccs vccs_deg_b4_nonde, by(vccsid)
		sum nonvccs_deg vccs_deg
		
		tempfile nonvccs_deg_b4_vccs
		save `nonvccs_deg_b4_vccs', replace
	
	restore
	
	** Merging in below-college-level indicators 
	merge n:1 vccsid using `nonvccs_deg_b4_vccs'
		assert _merge==3
		drop _merge		
		
	** Dropping students with prior non-VCCS degree
	drop if nonvccs_deg_b4_vccs == 1
	drop if vccs_deg_b4_nonde == 1
	drop nonvccs_deg_b4_vccs vccs_deg_b4_nonde
	disp "NO DEGREE PRIOR TO INITIAL VCCS ENROLLMENT"
	codebook vccsid	
			

*** Saving dataset for further analysis
	
	* Checking that data is still in student x term level
	isid vccsid strm
	
	* Total number of unique students
	codebook vccsid
	
	* Saving
	save "$working_data/all_term_level_restricted.dta", replace
