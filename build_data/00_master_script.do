*******************************************************************
***			MASTER SCRIPT FOR CREATING VCCS BUILD FILES			***
*******************************************************************

/*
This .do file contains all necessary steps for creating VCCS build files
for the eight file types: 
	Student
	Class
	Course
	Employment
	Financial Aid
	GPA 
	Graduation
	NSC 
	
This .do file specifies global macros to be used across all file-specific 
scripts.  It also calls do files that prepare outside data to be merged
into the VCCS data files. 
*/ 


clear all
set more off
capture log close 

********************************************************
*** Setting file paths for accessing and saving data ***
********************************************************

global user = c(username) 
	// this will store your local machine's username
	// for the purpose of defining file paths

global box = "/Users/$user/Box Sync"
	// adjust as needed if this is not the correct location
	// of your UVA Box folder
	
global git = "$box/GitHub"
	// adjust as needed if this is not the correct location
	// of where your GitHub repos are stored
	
global gitrepo = "$git/predictive_modeling_degree_completion_aera_open/build_data" 
	// corresponding GitHub repo for creating VCCS build files
	// SHOULD NOT BE ALTERED
	
global raw_data = "$box/VCCS restricted student data/Raw"
	// location of the raw data we received from VCCS (.csv files)
	// SHOULD NOT BE ALTERED

global build_data = "$box/VCCS restricted student data/Build"
	// location of where the completed build files will be stored
	// SHOULD NOT BE ALTERED
	
global codebook = "$build_data/Codebook"
global data_dictionary = "$codebook/Data Dictionary II.xlsx"
	// location of VCCS provided files that we will use 
	// to merge in additional information 
	// SHOULD NOT BE ALTERED

global built_crosswalks = "$build_data/Crosswalks"
	// to store built crosswalks created in build_all_crosswalks.do
	// SHOULD NOT BE ALTERTED
	
global logfile "$build_data/build_log"

capture log close
log using "$logfile", replace



*******************************************************
*** Setting switches for which build scripts to run ***
*** with first option for running all eight scripts ***
*******************************************************

local switch_all 			= 0
local switch_Student		= 0
local switch_Class			= 0
local switch_Course			= 0
local switch_Employment		= 0
local switch_FinancialAid	= 0
local switch_GPA			= 0
local switch_Graduation		= 0
local switch_NSC			= 1 


*** The following switches are for the NSC data - adjust these switches for
*** whether you would like to run the NSC enrollment or graduation data, or both.
*** Please note that either switch_NSC or switch_all must be set to 1 in order
*** for either of these NSC switches to work.  

local nsc_enrollment_switch = 1
local nsc_grad_switch 		= 0

***********************************************************
*** Setting switch that, if set to 1, will convert		*** 
*** all raw .csv files to .dta files.  This only needs	***
*** to be performed if new / updated data is received	***
*** from VCCS											***
***********************************************************

local switch_raw_to_dta 	= 0

*******************************************************************
*** Setting switch that, if set to 1, will read in information 	***
*** from VCCS provided codebook (see $data_dictionary) and 		***
*** other sources of information.  This only needs to be run	***
*** if additional information is incorporated into the script 	***
***	build_all_crosswalks.do										***
*******************************************************************

local switch_build_all_crosswalks 	= 0 

global cpi_adjust "2019Q4"
	// To be used to create real wages, using dollars as of $cpi_adjust
	// this can be updated to include the most recent quarter of data. 

	
*** Global containing each filetype
global filetypes "Student Class Course Employment FinancialAid GPA Graduation NSC"


*** Calling do file that creates crosswalks to be used across multiple file types
if `switch_build_all_crosswalks' == 1 {
	include "$gitrepo/02_build_all_crosswalks.do"
	}

*** Loop that executes the build file for all filetypes specified above in switches
foreach filetype of global filetypes {
if `switch_`filetype'' == 1 | `switch_all' == 1 {

	disp "`filetype'"
	clear
	
	* Setting filetype to be used to access and save file-specific data
	global filetype = "`filetype'"
	
	* Compiling all raw records to be used in *_build_master_use.do
	if `switch_raw_to_dta' == 1 {
		include "$gitrepo/01_raw_data_csv_to_dta.do"
		}
	
	* Creating file-specific build files
	include "$gitrepo/${filetype}_build_master_use.do"
	}
	}

	log close 







	
