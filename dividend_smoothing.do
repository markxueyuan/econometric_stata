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
global projectpath C:\Users\Xue\workspace\econometric_stata\
global datapath .\raw_data

** switch to working directory
cd $projectpath

** start logging
log using mylog , replace text

********************* import and merge data *********************


global mydata "$datapath\mydata"
global mydata_with_dividends "$datapath\mydata_with_dividends"
global mydata_collapsed "$datapath\mydata_collapsed"

program toimport
	syntax namelist [, save reshape]
	set more off
	tokenize `namelist'
	import excel using "$datapath\\`1'.xls" , cellrange(a8) firstrow clear
	duplicates drop ExcelCompanyID , force
	
	if "`save'" != "" {
		save "$mydata" , replace
	}
	else if "`reshape'" != "" {
		macro shift
		display "`*'"
		reshape long `*' , i(ExcelCompanyID) j(year)
	}
	
end

program toappend

	append using "$mydata"
	duplicates drop ExcelCompanyID , force
	save "$mydata" , replace
	
end

	



program tomerge
	syntax [, m:1]
	if "`m:1'" != "" {
		merge m:1 ExcelCompanyID using "$mydata"
	}
	
	else {
		merge 1:1 ExcelCompanyID year using "$mydata"
	}
	keep if _merge == 3
	drop _merge
	save "$mydata" , replace
end


** import private company

toimport private , save

** import public company

toimport public
toappend


** import dividends data

toimport dividends2 IQ_TOTAL_DIV_PAID_CF , reshape
tomerge , m:1

** import income data

toimport income2 IQ_NI IQ_EBIT , reshape
tomerge

tomerge

** import DPS

toimport DPS2 IQ_DIV_SHARE , reshape
tomerge

** import assets

toimport assets2 IQ_TOTAL_ASSETS IQ_NPPE , reshape
tomerge

** import estimates

toimport estimates2 IQ_EPS_EST_FY_ IQ_EPS_MEDIAN_EST_ IQ_EPS_STDDEV_EST_ IQ_EPS_NUM_EST_ IQ_EBIT_EST_ , reshape
tomerge

** import debts

toimport debts2 IQ_LIQ_VAL_PRE_CONV IQ_LIQ_VAL_PRE_N_RE IQ_LIQ_VAL_PRE_RE IQ_ST_DEBT_BNK IQ_LT_DEBT IQ_ST_DEBT_PCT IQ_ST_DEBT , reshape
tomerge

** import value

toimport values2 IQ_TOTAL_ASSETS IQ_TOTAL_LIAB IQ_TOTAL_EQUITY IQ_PREF_REDEEM IQ_PREF_NON_REDEEM IQ_PREF_CONVERT IQ_PREF_OTHER , reshape
tomerge

**import excel using "$datapath\assets2.xls" , cellrange(a8) firstrow clear

** import growth opportunities data

toimport opportunities2 IQ_PERIODDATE_BS IQ_MARKETCAP , reshape
tomerge

** import EPS

toimport EPS2 IQ_BASIC_EPS_INCL IQ_BASIC_EPS_EX , reshape
tomerge

** import repurchase
toimport repurchase2 IQ_COMMON_REP IQ_PREF_REP , reshape
tomerge

** import institutional

toimport institutional2 IQ_INSTITUTIONAL_SHARES IQ_INSTITUTIONAL_PERCENT , reshape
tomerge

** import more

toimport supplements2 IQ_OPER_INC IQ_T_TANGIBLE_FA_PR IQ_RE IQ_ISSUED_CAPITAL_P IQ_TOTAL_RESERVES_P IQ_TRADE_CREDITORS_P , reshape
tomerge

toimport more IQ_COMMON_DIV_CF IQ_DIVIDEND_YIELD IQ_EBITDA IQ_CUSTOM_BETA , reshape
tomerge

** import CPI

merge m:1 year using "$datapath\cpi2.dta"
keep if _merge == 3
drop _merge
save "$mydata" ,replace



****************** clean the data *****************************

** use "$mydata" , clear

** change string format to numeric format


foreach v of varlist IQ_* {
	capture confirm string variable `v'
	if !_rc {
		gen `v'_temp = real(`v')
		drop `v'
		rename `v'_temp `v'
	}
}

** drop financial firms (SIC codes between 6000 and 6999)

gen isfinance = regexm(SICCodes, "6[0-9][0-9][0-9]")

drop if isfinance == 1

save "$mydata" , replace



***************** calculate proxies *******************************
replace IQ_COMMON_DIV_CF = - IQ_COMMON_DIV_CF
replace IQ_TOTAL_DIV_PAID_CF = - IQ_TOTAL_DIV_PAID_CF


** dividends per share

generate DPS = IQ_DIV_SHARE

** earnings per share

generate EPS = IQ_BASIC_EPS_INCL

** payout ratio


gen payout_ratio =  IQ_COMMON_DIV_CF / IQ_NI

** dividend yield

gen dividend_yield = IQ_DIVIDEND_YIELD


** market to book ratio

generate book_assets = IQ_TOTAL_ASSETS // should be changed
generate book_equity = IQ_TOTAL_EQUITY // should be changed
generate market_equity = IQ_MARKETCAP
generate MAtoBA = (market_equity + book_assets - book_equity) / book_assets

** firm age

gen firm_age = 2016 - IQ_YEAR_FOUNDED

** firm size

gen firm_size = log(book_assets / CPI)


** leverage

generate short_term_debt = IQ_ST_DEBT
generate long_term_debt = IQ_LT_DEBT
generate leverage = (short_term_debt + long_term_debt) / book_assets

** asset tangibility

generate asset_tangibility = IQ_NPPE / IQ_TOTAL_ASSETS

** EBITDA ratio to asset

gen EBITAtoAsset = IQ_EBITDA / IQ_TOTAL_ASSETS

** institutional holdings

generate institutional_holdings = IQ_INSTITUTIONAL_PERCENT

** forecast dispersion

gen fcst_dispersion = IQ_EPS_STDDEV_EST_

** forecast deviation

gen fcst_deviation = abs(IQ_EPS_MEDIAN_EST_ - EPS)

** number of analyst

gen num_of_analyst = IQ_EPS_NUM_EST_

** equity beta

gen equity_beta = IQ_CUSTOM_BETA

** ROA

gen ROA = IQ_NI / book_assets


save "$mydata" , replace


/*


***************** descriptive statistics **************************



** data availability for each variable

foreach v of varlist IQ_* {
	quietly count if `v' != .
	display "`v': " r(N)
}


** data availability for each variable in the case of private company

foreach v of varlist IQ_* {
	quietly count if `v' != . & CompanyType == "Private Company"
	display "`v': " r(N)
}

** comparison of standard deviations of dividends between companies, standarized by the mean of deviations

use "$mydata_with_dividends" , clear

collapse (sd) sd_dividends = IQ_TOTAL_DIV_PAID_CF (mean) mean_dividends = IQ_TOTAL_DIV_PAID_CF (first) CompanyType , by(ExcelCompanyID)

gen sd_rel = sd_dividends / abs(mean_dividends)

bysort CompanyType : summ sd_rel

** compare dividend profit ratio between private and public held firms

use "$mydata_with_dividends" , clear

gen DPR = IQ_TOTAL_DIV_PAID_CF / IQ_NI

by CompanyType : summ DPR

** comparing companies with and without dividends data

use "$mydata" , clear

gen hasdiv = (IQ_TOTAL_DIV_PAID_CF != .)

bysort hasdiv : summ IQ_TOTAL_ASSETS if CompanyType == "Private Company"

bysort hasdiv : summ IQ_TOTAL_ASSETS if CompanyType == "Public Company"

*/

** what relates to dividend paying behavior

use "$mydata" , clear

collapse (first) CompanyType firm_age ///
		 (count) dividend_year_number = IQ_COMMON_DIV_CF ///
		 (median) DPS EPS payout_ratio dividend_yield MAtoBA firm_size ///
				  leverage asset_tangibility institutional_holdings ///
				  fcst_dispersion fcst_deviation equity_beta num_of_analyst ///
		 (sd) sd_returns = EBITAtoAsset , by(ExcelCompanyID)
		 
gen dividend_year_category = 0 if dividend_year_number == 0
replace dividend_year_category = 5 if  dividend_year_number >= 1 & dividend_year_number <= 5
replace dividend_year_category = 10 if dividend_year_number >= 6 & dividend_year_number <= 10
replace dividend_year_category = 15 if dividend_year_number >= 11 & dividend_year_number <= 15
replace dividend_year_category = 20 if dividend_year_number >= 16

export excel using "$datapath\div_year_num.xlsx" , firstrow(variables) 

import excel using "$datapath\payout_freq_vs_payout_ratio.xlsx" , firstrow clear

drop if payout_ratio > 1 | payout_ratio < -1

graph box payout_ratio if CompanyType == "Public Company", medtype(line) over(dividend_year_number) title(Public Company) ///
ytitle(Payout ratio) ysize(1) xsize(3)

graph box payout_ratio if CompanyType == "Private Company", medtype(line) over(dividend_year_number) title(Private Company) ///
ytitle(Payout Ratio) ysize(1) xsize(3)

import excel using "$datapath\payout_freq_vs_tangibility.xlsx" , firstrow clear

graph box asset_tangibility if CompanyType == "Public Company", medtype(line) over(dividend_year_number) title(Public Company) ///
ytitle(Asset Tangibility) ysize(1) xsize(3)

graph box asset_tangibility if CompanyType == "Private Company", medtype(line) over(dividend_year_number) title(Private Company) ///
ytitle(Asset Tangibility) ysize(1) xsize(3)

count if CompanyType == "Public Company"

count if CompanyType == "Private Company"

** keep samples having dividends data




***************** Lintner Model **********************************

use "$mydata" , clear

** drop if IQ_TOTAL_DIV_PAID_CF == .

drop if IQ_COMMON_DIV_CF == .

save "$mydata_with_dividends" , replace

program count_distinct , rclass
	args x
	tempvar order y
	gen long `order' = _n
	by `x' (`order') , sort : gen `y' = _n == 1
	sort `order'
	replace `y' = sum(`y')
	return scala cnt = `y'[_N]
end

program new_group
	args oldid newid
	by `oldid' , sort : gen `newid' = 1 if _n==1
	replace `newid' = sum(`newid')
	replace `newid' = . if missing(`oldid')
end


destring ExcelCompanyID , ignore ("IQ") replace
tsset ExcelCompanyID year

gen div_lag = L.IQ_COMMON_DIV_CF

gen div_dif = IQ_COMMON_DIV_CF - div_lag

gen alpha = .
gen theta = .
gen lambda = .
gen beta = .
gen obs = .


new_group ExcelCompanyID newid





count_distinct ExcelCompanyID

forvalues i = 1/`r(cnt)' {
	capture quietly regress div_dif IQ_NI div_lag [aweight= 1 / IQ_TOTAL_ASSETS]if newid == `i'
	if !_rc & e(N) > 7{
		matrix coeff = e(b)
		replace alpha = coeff[1,3] if newid == `i'
		replace theta = coeff[1,1] if newid == `i'
		replace lambda = -coeff[1,2] if newid == `i'
		replace beta = theta / lambda if newid == `i'
		replace obs = e(N) if newid == `i'
	}
}


save "$mydata_with_dividends" , replace


** bysort CompanyType : summ lambda beta

********************************** test *******************

******** collapse data 

use "$mydata_with_dividends" , clear

collapse (first) beta lambda CompanyType firm_age ///
		 (count) dividend_year_number = IQ_COMMON_DIV_CF ///
		 (median) DPS EPS payout_ratio dividend_yield MAtoBA firm_size ///
				  leverage asset_tangibility institutional_holdings ROA ///
				  fcst_dispersion fcst_deviation equity_beta num_of_analyst ///
		 (sd) sd_returns = EBITAtoAsset , by(ExcelCompanyID)
		 
save "$datapath\mydata_collapse" , replace

export excel using "$datapath\collapse.xlsx" , firstrow(variables) replace


********* dividends smoothing ************************

drop if lambda == .
drop if lambda > 1
drop if lambda < -1

graph box lambda if CompanyType == "Public Company", medtype(line) over(dividend_year_number) title(Public Company) ///
ytitle(Speed of Adjustment) ysize(2) xsize(3)

graph box lambda if CompanyType == "Private Company", medtype(line) over(dividend_year_number) title(Private Company) ///
ytitle(Speed of Adjustment) ysize(2) xsize(3)

******* ttest

use "$datapath\mydata_collapse" , clear

ttest lambda, by(CompanyType)

******* regression

** test asymmetric information assumption

bysort CompanyType : regress lambda MAtoBA firm_age firm_size asset_tangibility ///
									sd_returns payout_ratio fcst_dispersion ///
									fcst_deviation num_of_analyst institutional_holdings
									
									
** test agency cost assumption

bysort CompanyType : regress lambda MAtoBA payout_ratio institutional_holdings




*********** ROA *******************

use "$datapath\mydata_collapse" , clear

keep if ROA != . & ROA <= .5 & ROA >= -.5

graph box ROA if CompanyType == "Public Company", medtype(line) over(dividend_year_number) title(Public Company) ///
ytitle(Return on Assets) ysize(2) xsize(3)

graph box ROA if CompanyType == "Private Company", medtype(line) over(dividend_year_number) title(Private Company) ///
ytitle(Return on Assets) ysize(2) xsize(3)

********** Institutional Holding ********

use "$datapath\mydata_collapse" , clear


keep if institutional_holdings != .

graph box institutional_holdings if CompanyType == "Public Company", medtype(line) over(dividend_year_number) title(Public Company) ///
ytitle(Institutional Holdings) ysize(2) xsize(3)

graph box ROA if CompanyType == "Private Company", medtype(line) over(dividend_year_number) title(Private Company) ///
ytitle(Institutional Holdings) ysize(2) xsize(3)

