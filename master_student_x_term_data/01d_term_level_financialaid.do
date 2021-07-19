************************************************
*** TERM-LEVEL DATA FROM FINANCIAL AID FILES ***
************************************************

/*

This .do file uses the Financial Aid build files to create a long panel 
of student x term level data that tracks a subset of financial aid receipt
for each term in which the student appears in the financial aid data.

The resulting dataset $working_data/term_level_financialaid.dta contains the  
following student x term level information:

	(1) recaid: whether the student received any financial aid during that term
	(2) pell: amount of Pell grant the student received during that term
	(3) stafloans: amount of Stafford loans (subsidized + unsubsidized) the
			student received during that term
			
To populate pell and stafloans, I assume that the Pell and Stafford loan 
disbursements are distributed evening across all of the terms in which the 
student received aid during the academic year.  For example, if a student 
received $2000 in Pell aid for an academic year and received aid during the 
Summer term and the Fall term (but not the Spring term), then I assume the 
student received $1000 in the Summer term and $1000 in the Fall term. This is 
unlikely to be fully accurate in many cases, but its not possible to observe
precise term-level financial aid disbursements in the data. 				

*/

*** Macro for three terms to be used below
global terms "sum fal spr"

*** Converting Financial Aid files (academic year x student x college x repper)
*** to student x term level data. 
clear
local filelist: dir "$build_files/FinancialAid" files "*.dta.zip"
local filelist: list sort filelist
foreach file of local filelist {

	*local file = "FinancialAid_20162017.dta"

	disp "`file'"

	preserve
	
		zipuse "$build_files/FinancialAid/`file'", clear
		keep vccsid repyear repper aid* pell staloa staloun collnum 			///
			credfal credspr credsum 											///
			acg csap discaid gearup grantin grsef grsnbef hetap locgov msdawd 	///
			msdtfw othef othfed othin othoth outinst ptap schoin seog 			///
			smart tuiwaiv tviigrants vgap vocreh vsp							///
			cwsp stemef stemin loanef loanin perkins plusloa priloan tviiloans	
			
		* Combining subsidized and unsubsidized stafford loans
		gen stafloans = staloa + staloun
		
		* Sum of all grant/scholarship aid, based on N2FL categories of aid
		gen grantaid = acg + csap + discaid + gearup + grantin + grsef + ///
						grsnbef + hetap + locgov + msdawd + msdtfw + 	///
						othef + othfed + othin + othoth + outinst + ptap + ///
						schoin + seog + smart + tuiwaiv + tviigrants + ///
						vgap + vocreh + vsp + pell
			assert grantaid!=.
		
		* Sum of all loan aid, based on N2FL categories of aid
		gen loanaid = staloa + staloun + loanef + loanin + perkins + ///
					plusloa + priloan + tviiloans
			assert loanaid!=.
		
		* Sum of all workstudy aid, based on N2FL categories of aid
		gen workstudy = cwsp + stemef + stemin
		
		* Macro with all aid variables 
		global aidvars "pell stafloans grantaid loanaid workstudy" 
		
		
		* Creating terms labeled using $term names, using strm formating	
		tostring repyear, replace
		local sum = real("2"+substr(substr(repyear,1,4),3,2)+"3")
		local fal = real("2"+substr(substr(repyear,1,4),3,2)+"4")
		local spr = real("2"+substr(substr(repyear,5,4),3,2)+"2")
		disp "`sum' `fal' `spr'"
		
		
		* Collapsing from (student x collnum x repper) to (student x repper)  
		* 	by summing within aid and credits attempted,
		* 	and taking max of aid`term' indictor variables 
		collapse 	(sum) $aidvars ///
						credfal credspr credsum	///
					(max) aidsum aidfal aidspr ///
				, by(vccsid repper)
			
		* Filling in aid for specific terms
		* First, creating empty variables
		foreach var of global aidvars {
		foreach term of global terms {
			gen `var'``term'' = .
			}
			}
		
		* For Summer aid, using aid amounts from repper==1 observations		
		local term = "sum"			
		
			// a few observations (11 in 2009 and 2010 summers) 
			// have aidsum = 0 when student received some aid
			// in the the fall.  replacing aidsum = 1 for these observations.
			replace aidsum = 1 if repper==1 & ///
				(grantaid > 0 | loanaid >0 | workstudy > 0)
				
		gen recaid``term'' = aid`term' if repper==1
		foreach var of global aidvars { 
			replace `var'``term''= `var' if repper==1
			}
			
		* For Fall/Spring aid, dividing aid amounts from repper==5 observations
		* based on proportion of credspr and credfal
		replace credspr = 0 if aidspr==0
		replace credfal = 0 if aidfal==0
		gen credsprfal = credspr + credfal
		foreach term in fal spr {
		gen recaid``term'' = aid`term' if repper==5
		foreach var of global aidvars {
			replace `var'``term'' = `var' * (cred`term'/credsprfal) ///
				if repper==5
			}
			}

		* Collapsing from (student x repper) to (student)
		* by taking maximum cred`term' variables (which are duplicated within cell),
		* and summing aid amounts
		global aidvars_star ""
		foreach var of global aidvars {
			global aidvars_star "$aidvars_star `var'2*"
			}
		collapse 	(max) recaid* ///
					(sum) $aidvars_star ///
				, by(vccsid)
								

		* Reshaping to student x term level
		reshape long recaid $aidvars, i(vccsid) j(strm)
		
		* Tempfile to append below
		tempfile temp_financialaid
		save `temp_financialaid'
		
	restore
	
	append using `temp_financialaid'
					
	}
	
*** Setting aid values missing values to zero
	replace recaid=0 if recaid==.
	foreach var of global aidvars {
		replace `var' = 0 if `var'==.
		} 
		
*** Checking that all aid amounts are associated correctly with recaid
	foreach var of global aidvars {
		assert `var'==0 if recaid==0
		assert recaid==1 if `var'>0
		}

*** Saving	
	isid vccsid strm
	sort vccsid strm
	order vccsid strm recaid pell stafloans
	zipsave "$working_data/term_level_financialaid", replace
	clear all
