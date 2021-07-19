/******************************************************************************* 
					GRADUATION MASTER USE - BUILD FILE 			
*******************************************************************************/


*** Reading in Graduation academic year files 
*** which are created in ./raw_data_csv_to_dta.do
clear
local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
local filelist: list sort filelist
set obs 1
gen n = 1
foreach file of local filelist {

	disp "`file'"
	zipappend using "$raw_data/$filetype/dta files/`file'"

	}
	drop if n==1
	drop n
	
	
*** ACADPLAN *** 

	*** Identical code present in Student files 
	*** Please make any changes in both files

	* creating college x acadplan specific variable for merging purposes
	gen collnum_acadplan = collnum+"_"+acadplan
	
	* fixing acadplan values for NVCC, which end in "0" in the crosswalk
	* but not always in the student files
	replace collnum_acadplan = collnum_acadplan + "0" if ///
		strpos(collnum_acadplan,"280_")==1 & length(collnum_acadplan)==7
		
	* Fixing one-off strange values of acadplan
	replace collnum_acadplan = "284_624:7" if collnum_acadplan == "284_624   :7"
	
	* crosswalk created using VCCS files to include additional information
	* about acadplan
	merge m:1 collnum_acadplan using "$built_crosswalks/acadplan_crosswalk.dta", ///
		keep(master match)  
	tab collnum_acadplan if _merge==1
	drop _merge
	
	
** ADMIT_TERM ** 
	
	replace admit_term = "1"+admit_term if length(admit_term) == 3
	
	replace admit_term = "1883" if admit_term == "0883"
	
	assert length(admit_term) == 4 | admit_term == ""
		* if this returns an error, there was an error with the code above or you
		* have admit_terms of less than 3 digits, which should be looked at. 
	
** CURR ** 


	*** Identical code present in Student files 
	*** Please make any changes in both files
		
	rename curr_name curr_text
	
	assert length(curr) == 3 | curr == ""
		* if a curr value has fewer than 3 digits, then leading zeros 
		* will need to be added.
		* there should be no curr values with more than 3 digits
	
	* adjusting curr values to be the second three digits for all observations
	* with an acadplan corresponding to a Career Studies Certificate (CSC)
	replace curr=substr(acadplan,5,3) if 	strpos(acadplan,"221")==1 & ///
											length(acadplan)>=7 & ///
											real(substr(acadplan,5,3)) > 102
	tab file,m
	
	merge m:1 curr using "$built_crosswalks/curr_crosswalk.dta", ///
		keep(mas mat match_up match_con) ///
		update replace

	assert _m >= 3 | curr == "" | curr == "034" | curr == "642"
		drop _m
	
	replace acadplan_description = curr_text + " (from curr)" if acadplan_description==""
	tab curr_degree degree
	
	
** FSTTERM **
	
	* Creating common specification for four-digit fstterm
	replace fstterm = "1" + fstterm if length(fstterm) == 3
	replace fstterm = "1" + substr(fstterm,2,.) if substr(fstterm,1,1)=="0"
	
** JURIS ** 

	merge m:1 juris using "$built_crosswalks/juris_codebook", ///
		keepusing(juris_text) keep(master match) nogenerate
	
	assert length(juris) == 3 | juris == ""
		* if this returns an error, you have a value of juris which is the 	
			* incorrect length and could affect the creation of juris_instate.
	
	generate juris_instate = 1 if real(juris) < 900  
	replace juris_instate = 0 if juris == "." 
	

*** ADDING VARIABLE LABELS ***

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
		sheet(variable_labels_graduation) raw(old_name) clean(new_name) label(label) keepx namelabel
		
		
*** ADDING VALUE LABELS ***

	global value_label_vars "citz_status degrcde fstsem lstsem sortdeg"
	
	foreach var of global value_label_vars {
	
		encodefrom `var' using "$codebook/master_use_variable_labels.xlsx", ///
		filetype(excel) sheet(`var') raw(raw) clean(clean) label(label) allow_missing
		
	}	
	
*** ADDITIONAL DATA CHECKS ***

	assert vccsid != "" & vccsid != "."

	assert (citz_status >= 1 & citz_status <= 9) | citz_status == .	
	
	assert degrcde >=1 & degrcde <= 5
	
	assert fstsem >= 0 & fstsem <= 4
			* if this returns an error, there is a new value of fstsem of which 
			* we are unaware. 
		
	assert lstsem >= 0 & lstsem <= 4
			* if this returns an error, there is a new value of fstsem of which 
			* we are unaware. 	
			
	assert sortdeg >= 1 & sortdeg <= 6 & sortdeg != 5	
	tab file,m

*** DESTRINGING ***	
	
	global variables "acadyr birthyr collnum curr fstcen fstterm fstyr lstcen lstterm lstyr race gpa tcumhrs admit_term cip" 
	
	foreach var of global variables {
		
		destring `var' , replace
		
		}
	
*** SAVING ***
	
	** saving each academic year 
	local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
	local filelist: list sort filelist
	disp `filelist'
	replace file = file+".dta.zip"

	foreach file of local filelist {
	
	preserve
		keep if file=="`file'"
		local acadyear = substr("`file'",6,8)
		drop file
			
		sort vccsid lstterm acadplan
		zipsave "$build_data/$filetype/${filetype}_`acadyear'", replace		
	restore
	}

