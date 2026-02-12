/*******************************************************************************
Description:  	This file defines a program to merge two datasets, both before
				and after having removed a set of strings from the merge
				variables. The syntax is like regular stata merge. A normal 
				merge occurs first, and any unmatched observations are subject 
				to a second merge where the removal strings are removed from both	
				sets of merge variables.
				NB: At the moment, this program only works for merging on a single
				variable.
				NB: The behaviour of m:1 or 1:m matches is that any observations
				in the "1" dataset that directly matched are retained for the
				second round of matching.
				NB:	_merge==4 corresponds to the case where a match did not 
				originally occur but there was a match after removing the removal
				variables. This is different than regular Stata merge
*******************************************************************************/

capture program drop merge_rmstr
program define merge_rmstr

gettoken token 0 : 0, parse(" ,")

	syntax [varname(default=none)] using/, ///
		REMovestrings(string) ///
		[						///
		  ASSERT(string)		///	
		  GENerate(name)			///
		  KEEP(string)				///
		  KEEPUSing(string)			///
		  NOGENerate		///
		  CASEsensitive /// 
		]

	
	local mergevar `varlist'
	
	qui {
		
		* If 1:1 or 1:m merge, ensure mergevar uniquely identify master data
		if inlist("`token'", "1:1", "1:m") {
			isid `mergevar'
		}
		
		* Gen ID for master and save
		tempvar master_id
		gen `master_id' = _n
		tempfile master_data
		save `master_data'
		
		use "`using'", clear
		* If 1:1 or 1:m merge, ensure mergevar uniquely identify using data
		if inlist("`token'", "1:1", "m:1") {
			isid `mergevar' 
		}
		
		* Gen ID for using and save
		tempvar using_id
		gen `using_id' = _n
		tempfile using_data
		save `using_data'
		
		* Store list of variables in master data if keepusing is specified
		use `master_data', clear
		if "`keepusing'"!="" {
			ds
			local mastervars `r(varlist)'
		}
		
		* First pass at merging
		tempvar first_merge_name
		merge `token' `mergevar' using `using_data', gen(`first_merge_name')
		tempfile first_merge
		save `first_merge'
		
			
		* Data set of matched variables after merging.
		keep if `first_merge_name'==3
		tempfile first_merge_3
		save `first_merge_3'
		count
		if `r(N)'>0 {
			local has3 1
		}
		else {
			local has3 0
		}
		
		* Store IDs and names of using only
		use `first_merge' if `first_merge_name'==2, clear
		count
		if `r(N)'>0 {
			contract `using_id' `mergevar'
			drop _freq
			tempfile first_merge_2
			save `first_merge_2'
			local has2 1
		}
		else {
			local has2 0
		}
		
		* Store IDs and names of master only
		use `first_merge' if `first_merge_name'==1, clear
		count
		if `r(N)'>0 {
			contract `master_id' `mergevar'
			drop _freq
			tempfile first_merge_1
			save `first_merge_1'
			local has1 1 
		}
		else {
			local has1 0 
		}
		
		* In these cases (the unique side had everything merge in the first go) the maximal match already occured with the first pass, and the program should act like regular merge. 
		if (substr("`token'",1,1)=="1" & !`has2') | (substr("`token'",3,1)=="1" & !`has1') {
			use `first_merge', clear
			tempvar rmstr_merge
			gen `rmstr_merge' = `first_merge_name'
		}
		
		* This covers the rest of the cases
		else if `has1' | `has2' {
			* Clean up using data for 2nd merge
			use `using_data', clear
			if "`token'"=="1:1" | "`token'"=="1:m" {
				merge 1:1 `using_id' using `first_merge_2', nogen keep(3)
				foreach rmstr in `removestrings' {
					if "`casesensitive'"!="" {
						replace `mergevar' = subinstr(`mergevar', "`rmstr'", "", .)
					}
					else {
						replace `mergevar' = subinstr(`mergevar', substr(`mergevar',  strpos(lower(`mergevar'), lower("`rmstr'")),  strlen("`rmstr'")), "" , .)
					}
					replace `mergevar' = strtrim(`mergevar')
					drop if mi(`mergevar')
				}
				if "`token'"=="1:1" {
					merge 1:1 `mergevar' using `first_merge_3', nogen keep(1) keepusing(`mergevar')
				}
			}
			else {
				tempvar original_var
				gen `original_var' = `mergevar'
				foreach rmstr in `removestrings' {
					if "`casesensitive'"!="" {
						replace `mergevar' = subinstr(`mergevar', "`rmstr'", "", .)
					}
					else {
						replace `mergevar' = subinstr(`mergevar', substr(`mergevar',  strpos(lower(`mergevar'), lower("`rmstr'")),  strlen("`rmstr'")), "" , .)
					}
					replace `mergevar' = strtrim(`mergevar')
					drop if mi(`mergevar')
				}
				duplicates t `mergevar', gen(dup)
				drop if dup & !(`original_var'==`mergevar')
				drop dup `original_var'
			}

			tempfile using_data_unmatched
			save `using_data_unmatched'
			
			* Clean up master data for 2nd merge
			use `master_data', clear
			if ("`token'"=="1:1" | "`token'"=="m:1") {
				merge 1:1 `master_id' using `first_merge_1', nogen keep(3) keepusing(`mergevar')
				foreach rmstr in `removestrings' {
					if "`casesensitive'"!="" {
						replace `mergevar' = subinstr(`mergevar', "`rmstr'", "", .)
					}
					else {
						replace `mergevar' = subinstr(`mergevar', substr(`mergevar',  strpos(lower(`mergevar'), lower("`rmstr'")),  strlen("`rmstr'")), "" , .)
					}
					replace `mergevar' = strtrim(`mergevar')
					drop if mi(`mergevar')
				}
				if "`token'"=="1:1" {
					merge 1:1 `mergevar' using `first_merge_3', nogen keep(1) keepusing(`mergevar')
				}
			}
			else {
				tempvar original_var
				gen `original_var' = `mergevar'
				foreach rmstr in `removestrings' {
					if "`casesensitive'"!="" {
						replace `mergevar' = subinstr(`mergevar', "`rmstr'", "", .)
					}
					else {
						replace `mergevar' = subinstr(`mergevar', substr(`mergevar',  strpos(lower(`mergevar'), lower("`rmstr'")),  strlen("`rmstr'")), "" , .)
					}
					replace `mergevar' = strtrim(`mergevar')
					drop if mi(`mergevar')
				}
				duplicates t `mergevar', gen(dup)
				drop if dup & !(`original_var'==`mergevar')
				drop dup `original_var'
			}
			
			* Do the 2nd merge with cleaned data
			tempvar second_merge_name
			merge `token' `mergevar' using `using_data_unmatched', gen(`second_merge_name') keep(3)
			replace `second_merge_name'=4 if `second_merge_name'==3
			
			* Create crosswalk of IDs from each data set to merge
			keep `master_id' `using_id' `second_merge_name'
			tempfile second_merge_ids
			save `second_merge_ids'
			if `has3' {
				use `first_merge_3', clear
				contract `master_id' `using_id' `first_merge_name'
				drop _freq
				append using `second_merge_ids'
				tempvar rmstr_merge
				gen `rmstr_merge' = `first_merge_name'
				replace `rmstr_merge' = `second_merge_name' if mi(`rmstr_merge')
			}
			else {
				tempvar rmstr_merge
				gen `rmstr_merge' = `second_merge_name'
			}
			tempfile merge_ids
			save `merge_ids'
			
			* Merge the two data sets together, using the crosswalk that contains original and cleaned merges
			use `master_data', clear
			tempvar master_id_merge_name
			merge `token' `master_id' using `merge_ids', assert(1 3) gen(`master_id_merge_name')
			replace `rmstr_merge' = `master_id_merge_name' if `master_id_merge_name'==1
			drop `master_id_merge_name'
			replace `using_id' = rnormal() if mi(`using_id')
			tempvar using_id_merge_name
			merge `token' `using_id' using `using_data', gen(`using_id_merge_name')
			replace `rmstr_merge' = `using_id_merge_name' if `using_id_merge_name'==2
			drop `using_id_merge_name'
			assert !mi(`rmstr_merge')
		}
		
		else {
			disp as error "something is wrong in the cases!"
			error 498
		}
		
		
		* Clean up
		assert !mi(`rmstr_merge')
		forv i=1/4 {
			count if `rmstr_merge'==`i'
			local m`i' = `r(N)'
		}
		
		* Keep only specified using variables if option selected
		if "`keepusing'"!="" {
			keep `mastervars' `keepusing' `rmstr_merge'
		}
		
		* Deal with gen/nogen options
		if "`generate'"!="" {
			gen `generate' = `rmstr_merge'
		}
		else {
			if "`nogenerate'"=="" {
				gen _merge = `rmstr_merge'
			}
			local generate _merge
		}
		if "`nogenerate'"=="" {
			 cap label define merge_rmstr 1 "Master only" 2 "Using only" 3 "Matched directly" 4 "Matched after string removal"
			 la val `generate' merge_rmstr
		}
		
		* Deal with assert option
		if "`assert'"!="" {
			 local n: word count `assert'
			 local assert_expr assert inlist(`rmstr_merge'
			 forv i = 1/`n' {
				local merge_val: word `i' of `assert'
				local assert_expr `assert_expr', `merge_val'
			 }
			 local assert_expr `assert_expr')
			 cap `assert_expr'
			 if _rc != 0 {
			 	qui use `master_data', clear
				qui drop `master_id'
				di as smcl as err "after {bf:merge}, not all observations adhered to assert"
				di as err "(master data left in memory)"
				error 498
			 }
		}
		
		* Deal with keep option
		if "`keep'"!="" {
			tempvar tokeep
			gen `tokeep' = 0
			forv i=1/4 {
				if regexm("`keep'","`i'") {
					replace `tokeep' = 1 if `rmstr_merge'==`i'
				}
				else {
					local m`i' 0
				}
			}
			keep if `tokeep'
		}
		
		drop `rmstr_merge`'' `tokeep'
	}
	
	* Print results
	di
	di as smcl as txt _col(5) "Result" _col(33) "Number of obs"
	di as smcl as txt _col(5) "{hline 41}"
	di as smcl as txt _col(5) "Not matched" _col(30) as res %16.0fc (`m1'+`m2')
	di as smcl as txt _col(9) "from master" _col(30) as res %16.0fc `m1' as txt "  (`generate'==1)"
	di as smcl as txt _col(9) "from using" _col(30) as res %16.0fc `m2' as txt "  (`generate'==2)"
	di
	di as smcl as txt _col(5) "Matched" _col(30) as res %16.0fc (`m3'+`m4')
	di as smcl as txt _col(9) "directly" _col(30) as res %16.0fc `m3' as txt "  (`generate'==3)"
	di as smcl as txt _col(9) "after removal of `removestrings'" _col(30) as res %16.0fc `m4' as txt "  (`generate'==4)"
end