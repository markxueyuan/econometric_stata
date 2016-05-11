#delimit cr
capture log close
capture program drop _all
estimates drop _all
clear all


set more off
set rmsg on

set min_memory 4g
set max_memory 8g

global projectpath C:\Users\Xue\workspace\econometric_stata\
global datapath .\raw_data

cd $projectpath

log using mylog , replace text

************************************************
**** collect cusip-permno pairs in dsenames ****  Number 38418
************************************************

** ncusip-permno pairs

use "$datapath\dsenames.dta", clear

generate issuer_cusip = substr(ncusip,1,6)

drop if ncusip == ""

duplicates drop issuer_cusip permno , force

keep issuer_cusip permno

save "$datapath\using_ncusip.dta", replace

** cusip-permno pairs

use "$datapath\dsenames.dta", clear

generate issuer_cusip = substr(cusip,1,6)

drop if cusip == ""

duplicates drop issuer_cusip permno , force

keep issuer_cusip permno

** append ncusip-permno pairs to cusip-permno pairs

append using "$datapath\using_ncusip.dta"
duplicates drop issuer_cusip permno , force

save "$datapath\cusip_permno_pairs_dsenames.dta", replace


********************************************
**** collect cusip-permno pairs in fisd ****  Number 5029
********************************************


** issuer_cusip-permno pairs

use "$datapath\sample_fisd_20150317.dta", clear

duplicates drop issuer_cusip permno , force

drop if issuer_cusip == ""

keep issuer_cusip permno

save "$datapath\using_issuer_cusip.dta", replace


** cusip-permo pairs

use "$datapath\sample_fisd_20150317.dta", clear

drop issuer_cusip

generate issuer_cusip = substr(cusip,1,6)

duplicates drop issuer_cusip permno , force

drop if cusip == ""

keep issuer_cusip permno

** append issuer-cusip-permno pairs to cusip-permno pairs

append using "$datapath\using_issuer_cusip.dta"
duplicates drop issuer_cusip permno , force

save "$datapath\cusip_permno_pairs_fisd.dta", replace


**********************************
**** total cusip-permno pairs **** Number 39276
**********************************

** append dsenames to fisd

append using "$datapath\cusip_permno_pairs_dsenames.dta"
duplicates drop issuer_cusip permno , force

*********************************
**** make cusip->permno maps **** Number 36495
*********************************

duplicates drop issuer_cusip , force
save "$datapath\cusip_permno_maps.dta", replace

export delimited using "$datapath\index2.csv" , replace








