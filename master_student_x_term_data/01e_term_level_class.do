****************************************
*** TERM-LEVEL DATA FROM CLASS FILES ***
****************************************


*** Reading in each Class file separately
*** to collapse and then save as a tempfile
*** to be compiled at the end
global strms ""
local filelist: dir "$build_files/Class" files "*.dta.zip"
local filelist: list sort filelist

foreach file of local filelist {

	disp "`file'"
	zipuse "$build_files/Class/`file'", clear
	keep vccsid strm credit acad_group subject course_num grade ///
		day_eve_code instmod_text lec_lab_code
	
	** Term measure for this file, to be used when saving tempfile
	sum strm
	local strm = r(max)
	disp "`strm'"
	
	** Macros
		
		* Macros containing variables to collapse to student level
			global maxvars ""
			global sumvars ""
		
		* Macros containing variables created for any_* and credits_*
			global class_type ""
		
		
	** Total number of credits attempted 
		gen credits_class = credit
		global sumvars "$sumvars credits_class"
		
		
	** Developmental courses
		gen any_dev_all = acad_group=="DEV"
		gen any_dev_math = acad_group=="DEV" & ///
			(subject=="MTE" | subject=="MTH" | subject=="MTE")
		gen any_dev_eng = acad_group=="DEV" & ///
			(subject=="ENG" | subject=="ENF")
		gen any_dev_esl = acad_group=="DEV" & subject=="ESL"
		gen any_dev_other = acad_group=="DEV" & ///
			any_dev_math==0 & any_dev_eng==0 & any_dev_esl==0
		
		global dev_type "all math eng esl other"
		foreach type of global dev_type {
			global class_type "$class_type dev_`type'"
			}

	** Identifying type of courses and outcomes based on "grade" variable
	
		** Fixing grade values 
		replace grade = "D" if strpos(grade,"D")!=0
		replace grade = "F" if strpos(grade,"F")!=0
		replace grade = "X" if strpos(grade,"X")!=0
		
		** Non-credit courses: grades P, R, S, or U
			gen any_nocredit = grade=="P" | grade=="S" | grade=="U" | grade=="R" 

		** Withdrew from courses 
			gen any_withdrawn = grade=="W"

		** Failures (including incompletes) 
			gen any_failed = grade=="F" | grade=="I" 

		** Audited courses 
			gen any_audit = grade=="X"
		
		** Missing grades
			gen any_missinggrade = grade=="" | grade=="*" | grade=="N" | ///
				grade=="K" | grade=="("
				
			tab grade
			

		** Global of all possible course type / outcomes based on grade
		global class_type "$class_type nocredit withdrawn failed audit missinggrade"
		

	** Day / evening courses -- based on day_eve_code 

		gen any_day = day_eve_code=="D"
		gen any_evening = day_eve_code=="E"
		
		global class_type "$class_type day evening"


	** In-person versus online -- based on instmod

		gen any_online = 	instmod_text == "World Wide Web" | ///
							instmod_text == "World Wide Web - ER" 
								
		gen any_hybrid = 	instmod_text == "Blended -in Person & Web" | ///
							instmod_text == "Hybrid" | ///
							instmod_text == "In Person / Distance Learning"
								
		gen any_inperson = 	any_online==0 & any_hybrid==0
			// note that inperson courses also includes categories such as
			// videotape and television (probably distance courses) and 
			// also independent study and self-paced, which may not be in-person

		global class_type "$class_type online hybrid inperson"

		
	** Course levels

		* First, fixing course numbers to destring
			gen course_num2= course_num

			* First, removing leading zero for courses with four digits
			replace course_num2 = substr(course_num2,2,3) if ///
				strpos(course_num2,"0")==1 & length(course_num2)==4
				
			* Next, removing leading numeric characters
			replace course_num2 = subinstr(course_num2,"J","",.)
			replace course_num2 = subinstr(course_num2,"K","",.)
			replace course_num2 = subinstr(course_num2,"S","",.)
			replace course_num2 = subinstr(course_num2,"T","",.)
			replace course_num2 = subinstr(course_num2,"L","",.)
			
			* Destringing
			destring course_num2, replace
			
		* Making indicators for below-100, 100-level and 200-level courses
		gen any_below100 = course_num2!=. & course_num2 < 100
		gen any_100level = course_num2>=100 & course_num2 < 200
		gen any_200level = course_num2>=200 & course_num2!=.

		global class_type "$class_type below100 100level 200level"

		
	***College-level math
		* Defined as math course at or above 100 level
		gen any_collegemath = subject=="MTH" & course_num2 >= 100 & course_num2!=.
		
		global class_type "$class_type collegemath"

		
	** Lab science
		* Defined as science course at or above 100 level with a lab component
		gen any_labscience = lec_lab==1 & course_num2 >=100 & course_num2!=. & ///
			(subject=="BIO" | subject=="CHM" | subject=="GOL" | ///
				subject=="NAS" | subject=="PHY")
			// includes: Biology, Chemistry, Physics, Geology, and 
			// Natural Sciences (Astronomy, Human Biology, etc)
			
		global class_type "$class_type labscience"
		
		
	** Preparing for Collapse
		* For each class type, creating number of credits
			foreach type of global class_type {
				gen credits_`type' = credit if any_`type'==1
				}
				
		* Filling in maxvars and sumvars macros for collapse
			foreach type of global class_type {
				global sumvars "$sumvars credits_`type'"
				global maxvars "$maxvars any_`type'"
				}
		
	** Collapsing to student x term level data
		collapse (sum) $sumvars (max) $maxvars, by(vccsid strm)
		
		
	** Percent of credits in each category
		foreach type of global class_type {
			replace credits_`type'=0 if credits_`type'==.
			gen perc_`type' = credits_`type' / credits_class
			drop credits_`type' 
			}
		
	global strms "$strms `strm'"	
	tempfile class`strm'
	save `class`strm'', replace
	
}
	
	
*** Compiling all terms of data
clear
foreach strm of global strms {
	append using `class`strm''
	}	
		
		
*** Saving data
	sort vccsid strm
	order vccsid strm credits_class any_* perc_* 
	zipsave "$working_data/term_level_class", replace
	clear all
