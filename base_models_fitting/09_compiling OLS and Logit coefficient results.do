*** This script creates the cleaned data for Appendix Table A6 of the paper

*** This .do file reads in the raw results from the Logisitic and OLS Regressions
*** `model'_coef.csv, which are structured such that there is one row per predictor, 
*** and the coefficients, pvalues, and standard errors are in separate columns.
*** This .do file then formats the results into typical regression results, 
*** including significance stars at the customary levels, and having standard
*** errors reported below the coefficients within parantheses.  
*** This .do finally compiles the coefficient results into one file, and 
*** saves it in excel format in the same folder as the raw data.

global user = c(username) 

global box = "/Users/$user/Box Sync"

global project_folder = "$box/Predictive Models of College Completion (VCCS)/evaluation_results/truncated_predictors/cleaned_results"

global subfolder = "$project_folder/coefficients"

global crosswalk = "$box/Predictive Models of College Completion (VCCS)/predictor_name_crosswalk.csv"

* First, reading in predictor name crosswalk
import delimited using "$crosswalk", clear varnames(1)

	// fixing case issue
	replace predictor_meaning = subinstr(predictor_meaning,"(","",.)
	replace predictor_meaning = subinstr(predictor_meaning,")","",.)
	replace predictor_meaning = upper(substr(predictor_meaning,1,1))+substr(predictor_meaning,2,.)

	// saving tempfile
	tempfile crosswalk
	save `crosswalk', replace


foreach model in OLS Logit {
	insheet using "$subfolder/`model'_coef.csv", clear

	format coef std_err %5.4f
	gen st_coef = string(coef)
		replace st_coef = substr(st_coef,1,5) if strpos(st_coef,"-")==0
		replace st_coef = substr(st_coef,1,6) if strpos(st_coef,"-")==1
		replace st_coef = st_coef+"*" if pvalues <= 0.10
		replace st_coef = st_coef+"*" if pvalues <= 0.05
		replace st_coef = st_coef+"*" if pvalues <= 0.01
		
	gen st_std_err = string(std_err)
		replace st_std_err = substr(st_std_err,1,5)
		replace st_std_err = "(0" + st_std_err+ ")"
		
	drop pvalues coef std_err

	reshape long st_, i(v1) j(type) string

	sort type 
	rename st_ `model'
	
	tempfile `model'
	save ``model'', replace
	}


use `OLS', clear
merge 1:1 v1 type using `Logit'
	assert _merge==3
	drop _merge
	drop type
	rename v1 predictor_name
	drop if predictor_name=="const"
	
* Mergining in predictor meaning
merge n:1 predictor_name using `crosswalk'
	assert _merge==3
	drop _merge

	replace predictor_meaning = "" if predictor_meaning == predictor_meaning[_n-1] 
	rename predictor_meaning Predictor
	drop predictor_name 
	order Predictor OLS Logit

	
export excel using "$subfolder/OLS and Logit coefficient results, clean", ///
	replace firstrow(variables)
	
