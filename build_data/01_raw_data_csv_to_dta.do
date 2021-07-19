/******************************************************************************* 
					MASTER USE FILES	-	IMPORTING DATA					
*******************************************************************************/

/* 

This do file reads in raw $filetype files in .csv format from the raw_data. 
The script either saves them in a tempfile or in individual .dta files (in 
the case of Class and Employment) to be used in $filetype_master_use.do. This
file must be called from one of those files, since the locals are defined 
in $filetype_master_use.do

*/
 
local filelist: dir "$raw_data/$filetype" files "*.csv"
local filelist: list sort filelist
display `filelist'
foreach file of local filelist {
    disp "`file'"
	
	import delimited using "$raw_data/$filetype/`file'", clear stringcols(_all)
	
	* Creating file name variable to be referenced in build files
	* but replacing ".csv" with ".dta" so can be more easily
	* referenced in filetype specific build scripts
	gen file="`file'"
	replace file = subinstr(file,".csv","",.)
	
	local new_file = file 
	disp "`new_file'"
	
	* Saving .dta.zip versions of each raw file 
	zipsave "$raw_data/$filetype/dta files/`new_file'", replace

}


