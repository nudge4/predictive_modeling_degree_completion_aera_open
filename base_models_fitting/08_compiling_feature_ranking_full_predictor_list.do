*** This script create the cleaned data for Appendix Table A5 of the paper

/* 
This .do file reads in the raw feature ranking results for all predictors
across the four base models.  Specifically, the four .csv files are compiled 
in such a way that the first column is the predictor name, and the subsequent
four columns correspond to each of the four base models.  The ranking results
(e.g. 1 through 331) are listed for OLS and Logistic, while the feature importance
measures are listed for Random Forest and XGBoost.  The resulting file 
is saved as a .csv in the same location as the raw results.
*/

global user = c(username) 

global box = "/Users/$user/Box Sync"

global git = "$box/GitHub/predictive_modeling_degree_completion"

global project_folder = "$box/Predictive Models of College Completion (VCCS)"

global subfolder = "$project_folder/evaluation_results/truncated_predictors/cleaned_results/feature_ranking"

global models "OLS Logit RF XGBoost"

* First, reading in predictor name crosswalk
import delimited using "$crosswalk", clear varnames(1)

	// fixing case issue
	replace predictor_meaning = subinstr(predictor_meaning,"(","",.)
	replace predictor_meaning = subinstr(predictor_meaning,")","",.)
	replace predictor_meaning = upper(substr(predictor_meaning,1,1))+substr(predictor_meaning,2,.)

	// saving tempfile
	tempfile crosswalk
	save `crosswalk', replace


* Saving each CSV as a temp file 
foreach model of global models {
	import delimited using "$subfolder/`model'_feature_ranking.csv", clear
	
	* model-specific ranking/FI names
	capture rename ranking `model'_ranking
	capture rename feature_importance `model'_feature_importance
	
	tempfile `model'
	save ``model'', replace
	}
	
* Compiling results for all four models, starting with OLS
use `OLS', clear
	merge 1:1 predictor_name using `Logit'
		assert _merge==3
		drop _merge
	merge 1:1 predictor_name using `RF'
		assert _merge==3
		drop _merge
	merge 1:1 predictor_name using `XGBoost'
		assert _merge==3
		drop _merge	
	
* Merging in predictive meeting
merge n:1 predictor_name using `crosswalk'
	assert _merge==3
	drop _merge		
	
	order predictor_meaning
	drop predictor_name
		
* Sorting results based on OLS ranking
sort OLS_ranking

* Saving as csv in project subfolder
export delimited using "$subfolder/combined_feature_ranking.csv", replace
