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


use "$datapath\rpus_rv.dta" in 1/2, clear
use "$datapath\rpus_rv.dta" in 13000001/13000051, clear


use timestamp_utc rp_entity_id entity_type entity_name position_name rp_position_id country_code relevance ///
    topic group type sub_type property evaluation_method maturity category ///
	using "$datapath\rpus_rv.dta", clear
	
generate zz = _n
	
foreach v of varlist timestamp_utc-category{
	export delimited zz `v' using "$datapath\export\\`v'.csv" , replace
}

	
use ess aes aev ens ens_similarity_gap ens_key ens_elapsed g_ens g_ens_similarity_gap g_ens_key ///
    g_ens_elapsed event_similarity_key news_type source rp_story_id ///
	using "$datapath\rpus_rv.dta", clear

generate zz = _n
	
foreach v of varlist ess-rp_story_id{
	export delimited zz `v' using "$datapath\export\\`v'.csv" , replace
}


use rp_story_event_index rp_story_event_count product_key company isin css nip peq bee bmq bam ///
    bca ber anl_chg mcq ///
	using "$datapath\rpus_rv.dta", clear
	
generate zz = _n
	
foreach v of varlist rp_story_event_index-mcq{
	export delimited zz `v' using "$datapath\export\\`v'.csv" , replace
}


global rest g_ens_elapsed g_ens_key g_ens_similarity_gap isin maturity mcq news_type nip peq position_name ///
    product_key property relevance rp_entity_id rp_position_id rp_story_event_count rp_story_event_index ///
    rp_story_id source sub_type timestamp_utc topic type
	
use $rest using "$datapath\rpus_rv.dta", clear

generate zz = _n

export delimited zz $rest using "$datapath\export2\rest.csv" , replace
	

use "$datapath\sample_fisd_20150317.dta", clear

export delimited using "$datapath\fisd.csv" , replace

use "$datapath\dsenames.dta", clear
export delimited using "$datapath\dsenames.csv" , replace


generate issuer_cusip = substr(ncusip,1,6)

drop if ncusip == ""

duplicates drop issuer_cusip permno , force

keep issuer_cusip permno

duplicates drop issuer_cusip , force

save "$datapath\index.dta" , replace

use "$datapath\index.dta", replace

export delimited using "$datapath\index.csv" , replace


**********************

import delimited "$datapath\fisd_matched.csv", clear

save "$datapath\fisd_matched.dta", replace


use "$datapath\fisd_matched.dta", clear

** dependent variables
local dependents offering_yield treasury_spread

** news sentiments and news count
local sentiments ess aes
local stats mean median
local days 5 10 15 20 25 30 40 60
local news_type pr npr all

local news_counts
local news_sentiments

foreach s of local sentiments {
	foreach d of local days {
		foreach t of local news_type {
			foreach st of local stats {
				local ct "`s'_count_b`d'_`t'"
				local news_counts `news_counts' `ct'
				local st "`s'_`st'_b`d'_`t'"
				local news_sentiments `news_sentiments' `st'
			}
		}
	}
}




** maturity 
gen maturity_level = (date(maturity, "DMY") - date(offering_date, "DMY")) / 365
label variable maturity_level "Maturity Years"
local maturity_level maturity_level

** rating
label variable rating "Ratings"
local rating rating

/*

Calculation Method:

programmed in clojure

Order: S&P (rating_SP)> Moody’s(rating_mr)>Fitch(rating_ft)

sp	mr	fitch	rating
AAA	Aaa	AAA	1
AA+	Aa1	AA+	2
AA	Aa2	AA	3
AA-	Aa3	AA-	4
	A		6
A+	A1	A+	5
A	A2	A	6
A-	A3	A-	7
BBB+	Baa1	BBB+	8
BBB	Baa2	BBB	9
BBB-	Baa3	BBB-	10
BB+	Ba1	BB+	11
BB	Ba2	BB	12
BB-	Ba3	BB-	13
	B		15
B+	B1	B+	14
B	B2	B	15
B-	B3	B-	16
	Caa		18
CCC+	Caa1	CCC+	17
CCC	Caa2	CCC	18
CCC-	Caa3	CCC-	19
CC	Ca	CC	21
C		C	23
		DDD	25
		DD	25
D	C	D	25
NR	NR	NR	27


*/

** offering_amt
label variable offering_amt "Issue Size"
local offering_amt offering_amt

** convertible
label variable convertible "Convertible"
local convertible convertible

** private replacement
label variable private_placement "Private Placement"
local private_placement private_placement

** shelf registration
label variable rule_415_reg "Shelf Registration"
local rule_415_reg rule_415_reg

** secured dummy

generate secured = security_level == "SS"
label variable secured "Secured"

local secured secured

** callable dummy
generate callable = redeemable == 1
label variable callable "Callable"
local callable callable

** putable dummy
label variable putable "Putable"
local putable putable


** crisis

generate crisis = (date(offering_date, "DMY") > date("01Jul2007", "DMY")) ///
				  &                                                       ///
                  (date(offering_date, "DMY") < date("31Mar2009", "DMY"))

label variable crisis "Crisis"
local crisis crisis
				  
				  
** samples

keep if inlist(bond_type,"CDEB","CMTN")	
drop if yankee == 1
drop if permno_new == .
				  
** firm-year 			  

bysort permno_new issue_year : generate firm_year = 1 if _n == 1
replace firm_year = sum(firm_year)
label variable firm_year "Firm Year"
local firm_year firm_year


eststo: quietly ///
        regress offering_yield  ess_median_b30_npr ess_count_b30_pr maturity_level rating offering_amt ///
        convertible private_placement rule_415_reg secured callable putable crisis ///
		, vce(cluster firm_year)
		
eststo: quietly ///
        regress offering_yield  ess_mean_b30_npr ess_count_b30_pr maturity_level rating offering_amt ///
        convertible private_placement rule_415_reg secured callable putable crisis ///
		, vce(cluster firm_year)
		

esttab, ar2 label beta se ///
title("This is a regression table") ///
mtitles("Model A" "Model B" "Model C") ///
star(* 0.10 ** 0.05 *** 0.01) ///
addnote("Source: xxxxxxxx") ///
nonumbers

eststo clear




local control_variable  "`maturity_level' `rating' `offering_amt' `convertible' " + ///
        "`private_placement' `rule_415_reg' `secured' `callable' `putable' `crisis'"
		
display "`control_variable'"


