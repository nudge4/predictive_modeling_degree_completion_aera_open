
******************************************
*** TERM-LEVEL DATA FROM STUDENT FILES ***
******************************************

/*

This .do file uses the Student build files to create a long panel 
of student x term level data that tracks all student enrollment at 
VCCS colleges.  

The resulting dataset $working_data/term_level_student.dta contains the  
following student x term level information: 
	
	(1) Enrolled at VCCS college in term? 
	(2) VCCS college attended
	(3) Program of study information (acadplan, curr, cip, intended_degree, dual_enrollment)
	(4) Credits attempted (total_credit_hrs)
	(5) Number of VCCS colleges attended
	(6) FERPA flag (used for selecting students for research purposes)
	(7) Deomgraphic information (ps_sexcd, new_race, age, fhe, mhe)
	(8) HS graduation information (hs_grad, hs_grad_year)
	
If a student was enrolled at multiple colleges in a given term, then 
#2 and #3 display information from the college at which the student was
dual enrolled (this affects a very small number of students, < 100 per term).  

If dual enrollment is the same across the multiple colleges,
then #2 and #3 display information from the college at which the student
attempted the largest number of credit hours. 

If the student attempted the same 
number of credit hours at each college attended in that term, then the 
college-level observation for which #2 and #3 are populated is chosen randomly. 
This affects a few small number of students.  

#4 contains total number of credits attempted across all colleges.

Note that information in #7 and #8 may not be consistent within students,
over time.  This is particularly true for high school graduation information
for dual enrollment students, although there are still some inconsistencies
in high school graduation information for students who were never 
dually enrolled.

*/


*** Creating a long dataset containing observations for 
*** containing all student x term observations in which 
*** a student was enrolled at VCCS, according to Student files
clear
local filelist: dir "$build_files/Student" files "*.dta.zip"
local filelist: list sort filelist
foreach file of local filelist {

	preserve

		** Calling only necessary variables from Student files
		disp "`file'"
		zipuse "$build_files/Student/`file'", clear
		keep vccsid collnum acadplan curr total_credit_hrs 	///
				strm dual_enrollment intended_degree hs_grad	///
				gender new_race age fhe mhe cip ferpa	zip_us	///
				college campus home_campus						///
				distance_stud_to_coll acadplan_deglvl		
					
		local strm = strm
		disp "`strm'"
				
		** Collapsing from student x college to student-level
		** within term-level files
		
			* Number of colleges attended (sum in collapse)
			gen num_vccs_colleges = 1
			
			* Random number 
			set seed 1
			gen random=runiform()
			
			* Sorting first by (descending) dual enrollment participation 
			* and then by (descending) number of credit hours
			gsort vccsid -dual_enrollment -total_credit_hrs random
			
			* Collapsing
			collapse (sum) total_credit_hrs num_vccs_colleges		///
						(max) age mhe fhe new_race 					///
						(firstnm) dual_enrollment strm collnum		///
								acadplan curr intended_degree  		///
								acadplan_deglvl						///
								hs_grad_year gender cip ferpa		///
								distance_stud_to_coll,				///
				by(vccsid)
				
		** Renaming variables to specify source of information
		rename total_credit_hrs	enr_credits
		rename dual_enrollment 	enr_de
		rename collnum 			enr_collnum
		rename acadplan 		enr_acadplan
		rename curr 			enr_curr
		rename intended_degree 	enr_intended_degree
		rename cip				enr_cip
		rename acadplan_deglvl	enr_acadplan_deglvl
		
		sort vccsid
		tempfile terms_all_students
		save `terms_all_students'
		
	restore
		
	* Appending all term-level files containing all students
	append using `terms_all_students'

}	

*** Indicator that the student was enrolled at VCCS in the given term
	gen enr_vccs=1
	
*** Making race, gender, and high school graduation year consistent within student
*** Taking most recent, non-missing value of each within student

	* Numeric version of gender
	replace gender = "1" if gender == "M"
	replace gender = "2" if gender == "F"
	replace gender = "" if gender == "U"
	destring gender, replace
	
	* Creating new versions of variables to take most recent, non-missing value
	gsort vccsid -strm 
	bys vccsid: gen n=_n
	global consistency_vars "gender new_race hs_grad_year"
	foreach var of global consistency_vars {
		gen new_`var'=`var' if n==1
		replace new_`var'=new_`var'[_n-1] if new_`var'[_n-1]!=. ///
			& vccsid==vccsid[_n-1]
		replace new_`var' = `var' if new_`var'[_n-1]==. ///
			& vccsid==vccsid[_n-1] 
		drop `var'
		egen `var'=max(new_`var'), by(vccsid)
		drop new_`var'
		}
		
	* String version of gender
	tostring gender, replace
	replace gender = "M" if gender == "1"
	replace gender = "F" if gender == "2"
	replace gender = "U" if gender == "."
	
*** Saving
	isid vccsid strm
	sort vccsid strm
	order vccsid strm enr_vccs enr_credits enr_de enr_collnum enr_acadplan ///
		enr_cip enr_curr enr_intended_degree enr_acadplan_deglvl ///
		num_vccs_colleges age mhe fhe new_race gender ferpa ///
		distance_stud_to_coll 
	zipsave "$working_data/term_level_student", replace
	clear all


	
