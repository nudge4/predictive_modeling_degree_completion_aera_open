/******************************************************************************* 
					FINANCIAL AID MASTER USE - BUILD FILE 			
*******************************************************************************/


*** Reading in .dta versions of raw files (created in raw_data_csv_to_dta.do)
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
		
*** Replacing values of "NA" to "0" for dollar amount variables
*** This only affects one observation (vccsid = 4f63fabe21b96699, 2013-14) 
global dollar_var "acg athperc csap ctg ctgplus cwsp discaid gearup grantin" 
global dollar_var "$dollar_var grsef grsnbef hetap loanef locgov"
global dollar_var "$dollar_var msdawd msdtfw othef othfed othin othoth" 
global dollar_var "$dollar_var othst outinst pell perkins plusloa priloan ptap"
global dollar_var "$dollar_var schoin seog smart staloa staloun stemef" 
global dollar_var "$dollar_var stemin tuiwaiv tviigrants vgap vocreh wsot" 		

foreach var of global dollar_var {
	assert `var' != "NA" if vccsid!="4f63fabe21b96699"
	assert `var' != ""
	replace `var' = "0" if `var'=="NA"
	assert real(`var')!=.
	}
	
		
*** COLLNUM AND COLLEGE *** 

	destring fice, replace
		gen collnum=""
		replace collnum="291" if fice==6819
		replace collnum="292" if fice==4988
		replace collnum="287" if fice==4996
		replace collnum="279" if fice==3758
		replace collnum="284" if fice==3748
		replace collnum="297" if fice==8660
		replace collnum="283" if fice==3759
		replace collnum="290" if fice==4004
		replace collnum="298" if fice==8659
		replace collnum="299" if fice==9629
		replace collnum="275" if fice==5223
		replace collnum="280" if fice==3727
		replace collnum="285" if fice==3751
		replace collnum="277" if fice==9159
		replace collnum="282" if fice==9928
		replace collnum="278" if fice==9160
		replace collnum="276" if fice==8661
		replace collnum="294" if fice==7260
		replace collnum="293" if fice==6871
		replace collnum="295" if fice==3712
		replace collnum="296" if fice==7099
		replace collnum="286" if fice==3760
		replace collnum="288" if fice==3761
		
		merge m:1 collnum using "$built_crosswalks/collnum_names_codebook", ///
			keep(master match) nogenerate

*** BUDGET *** 	

	* replacing XXXXXX as missing
	replace budget="" if budget=="XXXXXX"
	
		
*** REPYEAR *** 
	
	* making this variable into "20072008" format rather than "0708"
	
	replace repyear = "20" + substr(repyear, 1, 2) + "20" + substr(repyear, 3, 2)


*** TAGU ***
	
	replace tagu = "0" if tagu == "0A"
	// only affects one observation, vccsid = 3c86b4ac79c63ade
	
	
*** ZIP ***
													
	* This variable holds a normal US 5-digit zip code:
	gen zip_us = substr(zip,1,5)
	
	replace zip_us = "." if !regexm(zip_us, "[0-9][0-9][0-9][0-9][0-9]")

	destring zip_us, replace 	
	
*** GENDER ***
	
	* Setting missing values of gender ("3" and "X") to one common missing 
	* value of "0"
	replace gender = "0" if gender=="3" | gender=="X"
		
*** DESTRINGING ***

	* doing a loop with a capture because almost all variables can 
	* be destrung.
	foreach var of varlist _all {
		capture nois destring `var', replace 
	}

		
*** ADDING VARIABLE LABELS ***

	renamefrom using "$codebook/master_use_variable_labels.xlsx", filetype(excel) ///
	sheet(variable_labels_financial_aid) raw(old_name) clean(new_name) label(label) keepx namelabel	
	
*** SAVING *** 

	** saving each individual year x term file
	local filelist: dir "$raw_data/$filetype/dta files" files "*.dta.zip"
	local filelist: list sort filelist
	disp `filelist'
	replace file = file+".dta.zip"

	foreach file of local filelist {
	
	preserve
		keep if file=="`file'"
		local acad_year=substr("`file'",2,8)
		drop file
			
		sort vccsid repper
		zipsave "$build_data/$filetype/${filetype}_`acad_year'", replace		
	restore
	}	

