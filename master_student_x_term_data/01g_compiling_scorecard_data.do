

*** Variables to keep from raw Scorecard data
global scorecard_keep_vars = "unitid opeid iclevel control adm_rate c150_4 c150_l4"
global scorecard_keep_vars = "$scorecard_keep_vars satvr25 satvr75 satmt25 satmt75"
global scorecard_keep_vars = "$scorecard_keep_vars actcm25 actcm75 md_earn_wne_p10 cdr3"

*** Reading in raw CSV data and selecting variable of interest

	** Academic years for each file in format `yr1'_`yr2'
	** Starting with 2000-01 academic year, up through most recently available
	** Current version of College Scorecard data was downloaded June 2020,
	** and includes up through 2018-19 (see $maxyr) 
	clear
	local maxyr = substr("$most_recent_scorecard",1,4)
	forvalues yr1 = 2000/`maxyr' {
		local yr2 = substr(string(`yr1'+1),3,2)
		disp "`yr1'_`yr2'"
		
		preserve
			clear
			import delimited using "$college_scorecard_data/MERGED`yr1'_`yr2'_PP.csv", ///
				case(lower)
			rename ïunitid unitid
			
			* If year doesn't have one/more of the keep_vars, 
			* creating that variable now so that "keep" command will operate
			foreach var of global scorecard_keep_vars {
				capture nois gen `var' = . 
				}
				
			* Keeping only variable specified above 
			* converting all to string format to facilitate appending
			keep $scorecard_keep_vars
			tostring $scorecard_keep_vars, replace
				
			* keeping track of academic year	
			gen acadyr = "`yr1'_`yr2'"
			tempfile `yr1'_`yr2'
			save ``yr1'_`yr2'', replace
		restore
		
		append using ``yr1'_`yr2''
		}
		
	** Fixing missing values and converting to numeric when applicable
	foreach var of varlist _all {
		capture replace `var'="" if `var'=="NULL"
		capture replace `var'="" if `var'=="PrivacySuppressed"
		capture destring `var', replace
		}
		
	** Saving acadyr x college level data		
	order acadyr $scorecard_keep_vars
	rename unitid ipeds
	isid ipeds acadyr
	sort ipeds acadyr
	zipsave "$working_data/college_scorecard_2000_01_to_${most_recent_scorecard}", replace
	
		
