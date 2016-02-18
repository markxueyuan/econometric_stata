#delimit cr
capture log close
capture program drop _all
estimates drop _all
clear all
set more off
set rmsg on

set min_memory 4g
set max_memory 5g

** data is put in the sub-directory named raw_data
local projectpath C:\Users\Xue\workspace\econometric_stata\
local datapath .\raw_data

** switch to working directory
cd `projectpath'

** start logging
log using mylog , replace text

import excel using "`datapath'\income2.xls" , cellrange(a8) firstrow

** reshape long NetIncomeFY@USDmmHi , i(ExcelCompanyID) j(year)
