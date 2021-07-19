**************************************
*** TERM-LEVEL DATA FROM GPA FILES ***
**************************************

/*

This .do file uses the GPA build files to create a long panel 
of student x term level data that tracks all credit accumulation and 
GPA -- both term level and cumulative -- for all terms in which the student
appears in the GPA data.

The resulting dataset $working_data/term_level_gpa.dta contains the  
following student x term level information:

	(1) Term-specific credits earned
	(2) Term-specific GPA
	(3) Cumulative credits earned
	(4) Cumulative GPA 
	
These are VCCS-wide measures of credits earned and GPA.

This data does not include attempted credits, because attempted credits 
in the GPA files do not include withdraws or incompletes. 
*/

*** Creating a long dataset containing student x term level 
*** observations for all terms in which the student was enrolled

	** Compiling all available GPA files
	clear
	local filelist: dir "$build_files/GPA" files "*.dta.zip"
	local filelist: list sort filelist

	set obs 1
	gen n = 1
	foreach file of local filelist {

		zipappend using "$build_files/GPA/`file'"
		
		}
		drop if n==1
		drop n
		
	destring strm, replace
		
	** Cumulative credits earned and GPA across all VCCS institutions: 
	** Needs to be calculated by first summing all credits and GPA points
	** earned in a given term, and then creating a cumulative variable 
	** that sums across colleges. 
	gen term_gpa_points = term_gpa * term_taken_credits
	drop term_gpa cum_gpa

	** Collapsing from student x college x term => student x term
	collapse (sum) term_*, by(vccsid strm) 
	
	** Creating cumulative credits earned/attempted and GPA points variables
	sort vccsid strm
	bys vccsid: gen cum_passed_credits = sum(term_passed_credits)
	bys vccsid: gen cum_taken_credits = sum(term_taken_credits)
	bys vccsid: gen cum_gpa_points = sum(term_gpa_points)
	
	** Creating term and cumulative GPA measure
	gen cum_gpa = cum_gpa_points / cum_taken_credits
	gen term_gpa = term_gpa_point / term_taken_credits
	
		// checking that term_gpa is populated where it should be
		assert term_gpa!=. if term_taken_credits>0
	
	** Setting term GPA to missing if zero credits taken/passed 
	replace term_gpa = . if term_passed_credits==0 & term_taken_credits==0
	assert term_gpa==. if cum_gpa==.

	** Replacing term_gpa from zero to missing when term_passed = term_taken
	** Replacing cum_gpa from zero to missing missing when term_passed = term_taken, 
	** and term_passed = cum_passed (likely, student's first term enrolled)
	** Per Yifeng, nearly all of these cases are for when students 
	** are only taking non-grade point classes (developmental, other pass/fail)
	replace term_gpa = . if term_gpa == 0 & ///
				term_passed_credits==term_taken_credits
	replace cum_gpa = . if cum_gpa == 0 & ///
				term_passed_credits == term_taken_credits & ///
				term_passed_credits==cum_passed_credits & ///
				term_taken_credits==cum_taken_credits
	
	** Dropping unnecessary variables
	drop cum_taken_credits *_gpa_points 
	
	** Checking consistency of cumulative credits earned
	sort vccsid strm
	assert cum_passed_credits!=.
	assert cum_passed_credits >= cum_passed_credits[_n-1] if vccsid==vccsid[_n-1]

	
*** Saving
	isid vccsid strm
	sort vccsid strm
	order vccsid strm term_taken_credits term_passed_credit term_gpa cum_passed_credits cum_gpa
	zipsave "$working_data/term_level_gpa", replace
	clear all
		
		
		
