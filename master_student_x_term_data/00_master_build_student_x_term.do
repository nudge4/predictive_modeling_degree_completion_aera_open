**************
*** MACROS ***
**************

global user = c(username) 

global box "/Users/$user/Box Sync"

global gitrepo "$box/GitHub/predictive_modeling_degree_completion_aera_open/Master_student_x_term_data"

global build_files "$box/VCCS restricted student data/Build"

global working_data "$box/VCCS restricted student data/Master_student_x_term_data"

global college_scorecard_data "$box/College Scorecard"

global most_recent_scorecard "2018_19"



*** Creating student x term level data files containing information
*** about enrollment and degree completion

	* Compiling unique list of vccsids present in the Student files
	include "$gitrepo/01a_compile_unique_vccsid_student_files.do"

	* Enrollment information from Student files
	include "$gitrepo/01b_term_level_student.do"
		// creates $working_data/term_level_student.dta

	* Current and cumulative GPA and credits earned from GPA files
	include "$gitrepo/01c_term_level_gpa.do"
		// creates $working_data/term_level_gpa.dta

	* Financial aid receipt from FinancialAid files
	include "$gitrepo/01d_term_level_financialaid.do"
		// creates $working_data/term_level_financialaid.dta

	* Information from Class files
	include "$gitrepo/01e_term_level_class.do"
		// creates $working_data/term_level_class.dta
		
	* VCCS graduation information from Graduation files
	include "$gitrepo/01f_term_level_grads_vccs.do"
		// creates $working_data/term_level_grads_vccs.dta
		
	* College Scorecard data preparation
	*include "$gitrepo/01g_compiling_scorecard_data.do"
		
	* Non-VCCS enrollment information from NSC files
	include "$gitrepo/01h_term_level_nsc_enr.do"
		// creates $working_data/term_level_nsc_enr.dta

	* Non-VCCS graduation information from NSC files
	include "$gitrepo/01i_term_level_nsc_grads.do" 
		// creates $working_data/term_level_grads_ncsc.dta
		
	* Compiling all student x term level data files created above
	include "$gitrepo/01j_compiling_term_level_data.do"
		// createds $working_data/all_term_level_data.dta
	
