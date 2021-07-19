
****************************************
*** COMPILING ALL TERM LEVEL RECORDS ***
****************************************

/* 

This .do file combines all student x term level data created in the files
01a through 01g.  The resulting file "$working_data/all_term_level_data.dta"
contains all student x term level information created in those do files.

Notes about how coverage differs across file types are found below.

*/ 


*** Starting with Student files
	zipuse "$working_data/term_level_student", clear
	global student_vars "enr_vccs enr_credits enr_de enr_collnum enr_acadplan"
	global student_vars "$student_vars enr_curr enr_de enr_intended_degree num_vccs_colleges"
	order vccsid strm $student_vars
	assert enr_vccs==1
	
*** Merging in Class files
	// 1:1 merge on vccsid strm
	sort vccsid strm
	zipmerge vccsid strm using "$working_data/term_level_class"
		rename _merge merge_class
		tab strm merge_class
		
	global class_vars "credits_class any_dev_all any_dev_eng any_dev_esl any_dev_other"
	global class_vars "$class_vars any_nocredit any_withdrawn any_failed any_audit"
	global class_vars "$class_vars any_missinggrade any_day any_evening any_online"
	global class_vars "$class_vars any_hybrid any_inperson any_below100 any_100level"
	global class_vars "$class_vars any_200level any_collegemath any_labscience"
	global class_vars "$class_vars perc_dev_all perc_dev_eng perc_dev_esl perc_dev_other"
	global class_vars "$class_vars perc_nocredit perc_withdrawn perc_failed perc_audit"
	global class_vars "$class_vars perc_missinggrade perc_day perc_evening perc_online"
	global class_vars "$class_vars perc_hybrid perc_inperson perc_below100 perc_100level"
	global class_vars "$class_vars perc_200level perc_collegemath perc_labscience"
		// Virtually 100% merge for Class files Fall 2003 and onward

		// Summer 2000 through Summer 2003: 
		// 		Only ~1/3 of records from Student files have a match in Class files
		//		There are also a few thousand records in the Class files 
		//		(roughly 10% of Class records) that are not present in the
		//		Student files.  Therefore, replacing all Class variables with 
		// 		missing for terms prior to Fall 2003
		foreach var of global class_vars {
			replace `var' = . if strm <= 2033
			}
		drop if merge_class==2 & strm <=2033
		
		// Fall 2003 and onward: 
		// 		Only 5 observations in Summer 2009 do not match: 
		//		2 from Student, 3 from class
		// 		Dropping 3 observations from Summer 2009 not present in Student files
		drop if merge_class==2 & strm==2093
		
		// 		there are also 5 students in Summer 2018 and 2 students in Fall 2018
		// 		present in the Student files, but not present in the Class files
		// 		Finally, there are 3 students in Spring 2019 present in the Class file
		// 		but not present in the Student files.  Dropping these 3 students.
		drop if merge_class==2 & strm==2192
		
		// Data currently contains all student x term observations present in Student files
		drop merge_class
		isid vccsid strm
		assert enr_vccs==1
	
*** Merging in GPA files
	// 1:1 merge on vccsid strm
	sort vccsid strm
	zipmerge vccsid strm using "$working_data/term_level_gpa"
		rename _merge merge_gpa
	global gpa_vars "term_taken_credits term_passed_credits cum_passed_credits term_gpa cum_gpa" 
		
	* Merge status by term
	tab strm merge_gpa
		// prior to Spring 2005, roughly half of observations in the Student files
		// do not have a corresponding observation in the GPA files
		// For this reason, removing GPA information prior to Spring 2005
		foreach var of global gpa_vars {
			replace `var'=. if strm < 2052
			}
		// Very few observations in the Student files that don't appear in the 
		// GPA files; the majority of these are Spring 2005-Spring 2006
		
	* Credits earned for GPA-only observations
	tab term_taken_credits if merge_gpa==2 & strm>=2052,m
		// 99.9% of GPA-only observations have zero term_taken_credits
	tab strm if merge_gpa==2 & term_taken_credits>0 & term_taken_credits!=.
		// remaining n = 7,223 observations are spread out across the terms
		// dropping all merge_gpa=2 observations 2005 and after
		drop if merge_gpa==2
		
		// Data currently contains all student x term observations present in Student files
		tab merge_gpa
		drop merge_gpa
		isid vccsid strm
		assert enr_vccs==1
			
	
*** Merging in Financial Aid records
	// 1:1 merge on vccsid strm
	sort vccsid strm
	zipmerge vccsid strm using "$working_data/term_level_financialaid"
		rename _merge merge_financialaid
	global financialaid_vars "recaid credaid pell stafloans" 
	
	* Merge status by term
	tab strm merge_financialaid
		// No financial aid data currently available before Summer 2007 
		// or after Spring 2019
	
	* Dropping financial aid observations without corresponding observation
	* in Student enrollment files.  Maybe these are for students who have
	* enrolled at a different public Virginia institution? 
	drop if merge_financialaid==2
	
		// Data currently contains all student x term observations present in Student files
		gen fa_record=merge_financialaid==3
		drop merge_financialaid
		isid vccsid strm
		assert enr_vccs==1
		

*** Merging in NSC enrollment records
	// 1:1 merge on vccsid strm
	sort vccsid strm
	zipmerge vccsid strm using "$working_data/term_level_nsc_enr"
		rename _merge merge_nsc_enr
		
		* Merge status by term
		tab strm merge_nsc_enr
			// No NSC enrollment records prior fo 2004
			// There are NSC enrollment records past the Student files: 
			// Specifically, there are currently 68k observations in Summer 2018.
		
		* Setting enr_nonvccs = 0 for Student-only observations
		replace enr_nonvccs = 0 if merge_nsc_enr==1
		assert enr_nonvccs!=. 
		
		* Setting enr_vccs = 0 for NSC-only observations
		replace enr_vccs = 0 if merge_nsc_enr==2
		assert enr_vccs!=.

		drop merge_nsc_enr
		isid vccsid strm
		
		// Data now contains all student x term observations present in either 
		// Student or NSC enrollment files, for all unique vccsids present in 
		// the Student files.  If the student was enrolled at both
		// a VCCS and non-VCCS college during the same term, that information will
		// be contained in the same student x term observation (row)
		
		
*** Merging in VCCS graduation records
	// 1:1 merge on vccsid strm
	sort vccsid strm
	zipmerge vccsid strm using "$working_data/term_level_grads_vccs"
		rename _merge merge_vccs_grad
		
		* Merge status by term
		tab strm merge_vccs_grad
			// Currently no VCCS graduation records prior to Summer 2006
		
		* Setting grad_vccs = 0 for Student-only observations
		replace grad_vccs = 0 if merge_vccs_grad==1
		assert grad_vccs!=.
		
		* Setting enrollment indicators to zero for Graduation-only observations
		replace enr_vccs = 0 if merge_vccs_grad==2
		replace enr_nonvccs = 0 if merge_vccs_grad==2
		assert enr_vccs!=. & enr_nonvccs!=.
			// There are many students who earn their degrees one or two
			// terms after their last term of enrollment at VCCS
			
		drop merge_vccs_grad
		isid vccsid strm
		
		// Data now contains all student x term observations present in any of
		// the files: Student, NSC (enrollment), Graduation (VCCS), 
		// for all unique vccsids present in the Student files.  If the 
		// student earned a degree during a term in which they were enrolled
		// at either VCCS or non-VCCS college, this information is contained 
		// in the same student x term observation (row)
		
		
*** Merging in non-VCCS graduation records
	// 1:1 merge
	sort vccsid strm
	zipmerge vccsid strm using "$working_data/term_level_grads_nsc"
		rename _merge merge_nsc_grad
		
		* Merge status by term
		tab strm merge_nsc_grad
			// no NSC graduation records prior to 2004
			// most graduation records start Fall 2004
			// NSC graduation records after Spring 2018 
		
		* Setting grad_nonvccs and grad_vccs_nsc = 0 for master-only observations
		replace grad_nonvccs = 0 if merge_nsc_grad==1
		replace grad_vccs_nsc = 0 if merge_nsc_grad==1
		assert grad_nonvccs!=.
		
		* Setting enrollment and VCCS grad indicators to zero 
		* for NSC degree-only observations
		replace enr_vccs = 0 if merge_nsc_grad==2
		replace enr_nonvccs = 0 if merge_nsc_grad==2
		replace grad_vccs = 0 if merge_nsc_grad==2
		assert enr_vccs!=. & enr_nonvccs!=. & grad_vccs!=.
		
		drop merge_nsc_grad
		isid vccsid strm
		
		// Data now contains all student x term observations present in any of
		// the files: Student, NSC (enrollment), Graduation (VCCS), and NSC (degrees), 
		// for all unique vccsids present in the Student files.
		// If the student earned a degree during a term in which they were enrolled
		// at either VCCS or non-VCCS college or earned a VCCS degree, 
		// this information is contained in the same student x term observation (row)
		
*** Checking that each row corresponds to at least one enrollment or degree occurence
	assert enr_vccs==1 | enr_nonvccs==1 | grad_vccs==1 | grad_nonvccs==1 | grad_vccs_nsc==1
	
	
*** Creating measure for term such that: 
*** term = term[_n-1] + 1 for all consecutive terms
	egen term_consec = group(strm), label
		// 1 = 2003
		// 2 = 2004
		// 3 = 2012
		// etc
			
*** Saving all student x term level enrollment and graduation data
	sort vccsid strm
	zipsave "$working_data/all_term_level_data", replace
	
	
	

		
