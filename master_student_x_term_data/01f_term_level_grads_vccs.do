*********************************************
*** TERM-LEVEL DATA FROM GRADUATION FILES ***
*********************************************

/*

This .do file uses the Graduation build files to create a long panel 
of student x term level data that tracks VCCS credentials awarded.

The resulting dataset $working_data/term_level_grads_vccs.dta contains the  
following student x term level information: 

	(1) Program of study (grad_curr)
	(2) Degree level: degree_level_vccs (three possible values to correspond with NSC)
				and degree_level_vccs_exp (full information from graduation files
			
Note that the dataset contains information for only one credential per term.
The credential described is the one with the highest level, with 
Associate > Certificate > Diploma.  This can be easily changed by omitting the line
 "keep vccsid strm grad_curr1..."

*/


*** Compiling all VCCS Graduation files
clear
local filelist: dir "$build_files/Graduation" files "*.dta.zip"
local filelist: list sort filelist

set obs 1
gen n = 1
foreach file of local filelist {
	zipappend using "$build_files/Graduation/`file'"		
	}
	drop if n == 1
	drop n
	
*** Keeping only necessary variables
	keep vccsid curr degree lstterm collnum acadplan cip
	duplicates drop
			
*** Renaming variables
	rename curr grad_curr
	rename lstterm strm
	rename collnum grad_collnum
	rename cip grad_cip
	rename acadplan grad_acadplan
	
		// lstterm = graduation term
		
*** Degree level to be consistent with NSC files 
gen degree_level_vccs = ""
	replace degree_level_vccs = "Diploma" if degree=="DIPL"
	replace degree_level_vccs = "Certificate" if degree=="CERT" | degree=="CSC"
	replace degree_level_vccs = "Associate" if substr(degree,1,1)=="A"
	assert degree_level_vccs!=""
	
	** Creating student-level dataset that includes when the student
	** earned which type of degree -- includes all degrees earned at non-VCCS,
	** not just highest level 
	preserve
		* Indicator for earning each type of degree
		* (max) in collapse
		gen deg_vccs_associate = degree_level_vccs=="Associate"
		gen deg_vccs_certificate = degree_level_vccs=="Certificate"
		gen deg_vccs_diploma = degree_level_vccs=="Diploma"
		
		* first term earned that type of degree 
		* (min) in collapse
		foreach type in associate certificate diploma {
			gen deg_vccs_`type'_strm = strm if deg_vccs_`type'==1 
			}
			
		* collapse globals
		global collapse_min ""
		global collapse_max ""
		foreach type in associate certificate diploma {
			global collapse_max "$collapse_max deg_vccs_`type'"
			global collapse_min "$collapse_min deg_vccs_`type'_strm"
			}
			
		* collapsing to student level
		collapse (max) $collapse_max (min) $collapse_min, by(vccsid)
		
		* saving as separate file
		zipsave "$working_data/student_level_vccs_degree_type_strm", replace
	restore
	
*** Also keeping more specific degree types 	
rename degree degree_level_vccs_exp
	
*** Reshaping wide to student x term, as some students
*** earn multiple degrees in the same term
*** First degree recorded will be the highest level
*** with Associate > Certificate > CSC > Diploma
*** If multiple degrees within same level, then degrees are sorted by 
*** Curriculum.

	* Creating separate degree level variable with Certificate > CSC
	* But treating all Associate degrees as the same
	gen sort_degree_level = degree_level_vccs
	replace sort_degree_level = "Csc" if degree_level_vccs_exp == "CSC"

	gsort vccsid strm sort_degree_level -grad_curr
	drop sort_degree_level
	bys vccsid strm: gen n=_n
	reshape wide 	degree_level_vccs degree_level_vccs_exp ///
					grad_curr grad_collnum grad_cip grad_acadplan, ///
		i(vccsid strm) j(n)
		
	* How many students earned multiple degrees per term
	preserve
		gen mult_degrees_per_term = degree_level_vccs2!=""
		tab mult_degrees_per_term
		
		collapse (max) mult_degrees_per_term, by(vccsid)
		tab mult_degrees_per_term
		// 15% of graduates earned multiple credentials in one term
	restore
		
	* For now, just keeping highest degree earned in a term
	keep vccsid strm grad_curr1 degree_level_vccs1 degree_level_vccs_exp1 ///
		 grad_collnum1 grad_cip1 grad_acadplan1
	rename grad_curr1 grad_curr
	rename grad_collnum1 grad_collnum
	rename degree_level_vccs1 degree_level_vccs
	rename degree_level_vccs_exp degree_level_vccs_exp
	rename grad_cip1 grad_cip
	rename grad_acadplan1 grad_acadplan
		
*** Indicator that student graduated from VCCS during this term		
	gen grad_vccs = 1	
	
*** Removing any vccsids not present in Student files
	// n:1 merge on vccsid 
	sort vccsid
	zipmerge vccsid using "$working_data/unique_vccsid_student_files"
		tab _merge
		codebook vccsid if _merge==1
		tab strm _merge
		// total of n = 1,448 graduation records (n = 1360 unique students)
		// who are in the Graduation files, but not in Student files
		// majority of these are graduation records in 2004 or earlier
		drop if _merge!=3
		drop _merge	
	
*** Saving
	isid vccsid strm
	sort vccsid strm
	order vccsid strm grad_vccs grad_curr degree_level_vccs ///
		degree_level_vccs_exp grad_collnum grad_acadplan ///
		grad_cip
	zipsave "$working_data/term_level_grads_vccs", replace
