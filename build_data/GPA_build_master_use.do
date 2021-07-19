/******************************************************************************* 
							GPA MASTER USE FILES						
*******************************************************************************/

*** Reading in GPA term files which are created in ./raw_data_csv_to_dta.do
clear
local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
local filelist: list sort filelist
display `filelist'
set obs 1
gen n = 1
foreach file of local filelist {

	disp "`file'"
	zipappend using "$raw_data/$filetype/dta files/`file'"

	}
	drop if n==1
	drop n
	
	assert vccsid != "." & vccsid != ""
		* if this returns an error, you are missing the vccsid for an observation. 
		
	* within term, data uniquely identified by vccsid and collnum
	isid strm vccsid collnum

*** YEAR ***

	assert substr(strm,1,1)=="2"
		// if this test fails, then it indicates that there is data
		// out of the range of expected values (e.g. from the year 1999)
		
	generate year = "20" + substr(strm, 2, 2)
	destring year, replace 

	assert (2000 <= year <= 2018) & !missing(year)
		// this will need to be changed with new data, but if it returns 
		// an error the previous code needs to be fixed, or you have a data error
		// concerning "strm"

*** TERM ***

	* creating a term variable similar to other file structures
	gen term = "" 
	replace term = "6_fae" if substr(strm, -1, 1) == "4"
	replace term = "3_spe" if substr(strm, -1, 1) == "2"
	replace term = "4_sue" if substr(strm, -1, 1) == "3"

	assert term != "." | term != ""

*** COLLNUM *** 

	* merging in college names (collnum_text)

	merge m:1 collnum using "$built_crosswalks/collnum_names_codebook", ///
		keep(master match) nogenerate
	
*** SETTING CUM_GPA TO CUR_GPA FOR OUTLIER STUDENT
	
	replace cum_gpa=cur_gpa if vccsid=="f8eb41bb4267cd50" & strm=="2032"
	count if vccsid=="f8eb41bb4267cd50"
	assert r(N)==1
	* The cum_gpa values for this student is 28.564.  
	* This student is not present in the Student or Class files.  
	* If this student re-enrolls, then the assert command will fail. 

	
*** RENAMING + LABELS ***

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
		sheet(variable_labels_GPA) raw(old_name) clean(new_name) label(label) keepx namelabel
		
*** FINAL ASSERT CHECKS *** 	

		destring term_gpa, replace 
	assert term_gpa <= 4 
		// if this returns an error, there is an out-of-range value for term_gpa
	assert real(cum_gpa) <= 4 | (vccsid == "a179898b04b6d15c" | vccsid == "f8eb41bb4267cd50")
		// if this returns an error, there is an out-of-range value for cum_gpa


*** ORDERING & DESTRINGING ***

	order vccsid collnum collnum_text institution year term term_gpa ///
		term_passed_credits term_taken_credits cum_gpa cum_passed_credits ///
		cum_taken_credits strm file 

	** Destring all relevant variables
	
	global variables "term_passed_credits term_taken_credits " 
	
	foreach var of global variables {
		
		destring `var' , replace
		
		}
	
*** SAVING *** 
	
	** saving each individual year x term file
	local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
	local filelist: list sort filelist
	disp `filelist'
	replace file = file+".dta.zip"

	foreach file of local filelist {
	
	preserve
		keep if file=="`file'"
		local strm=substr("`file'",4,4)
		local year=substr("`file'",4,1)+"0"+substr("`file'",5,2)
		if substr("`file'",7,1)=="2" local term="3_spe" 
		if substr("`file'",7,1)=="3" local term="4_sue" 
		if substr("`file'",7,1)=="4" local term="6_fae" 		
		disp "`year' `term' `strm'"
		drop file
			
			* change to year and term, to match other datasets??? *** 
		sort vccsid collnum
		zipsave "$build_data/$filetype/${filetype}_`year'_`term'", replace		
	restore
	}

