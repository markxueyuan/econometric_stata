#delimit cr
capture log close
capture program drop _all
estimates drop _all
clear all


set more off
set rmsg on

set min_memory 4g
set max_memory 5g

/******************************************************
	STEP (0): Preparations
	
	Designate workpath,
	open log,
	prepare data, load factory functon
	
	project map:
	
	--projectpath\
		--raw_data\
			--cr_data_later.dta
		--dd.do (<- you are here)
		--factory.do
	
******************************************************/

** designate projectpath and datapath
** data is put in the sub-directory named raw_data
local projectpath C:\Users\Xue\workspace\econometric_stata\
local datapath .\raw_data

** switch to working directory
cd `projectpath'

log using mylog , replace text

import delimited using "`datapath'\tnic3_allyears_extend_scores.txt", varnames(1) clear

save "`datapath'\tnic3_allyears_extend_scores.dta", replace

import delimited using "`datapath'\FluidityDataExtend.txt", varnames(1) clear

tempfile file1

save "`file1'"

import delimited using "`datapath'\TNIC3HHIdata_extend.txt", varnames(1) clear

merge 1:1 gvkey year using `file1'
keep if _merge == 3
drop _merge

save "`datapath'\fluidity.dta", replace

