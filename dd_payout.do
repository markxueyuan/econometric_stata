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
			--controls.dta
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

** load data
use "`datapath'\controls.dta"
** make data time-series
tsset gvkey fyear

** load factory functions
do "factory.do"

/******************************************************
	STEP (1): Prepare input varlists for nnmatch
******************************************************/

** (1.1) Group the variables that will be used later

local payoutvar payout_yd dv_yd repur_yd
local cdsvar cdsactive
local cdsdeterm sprate ff48 lnat cash2at profit2at bklev mb1 fcf2at ///
                cfvol firmage nlosses tang_a sale_a roa inv_a ior abret stkvol stkpct optpct ///
                wcap_a re_a
local varlist_exact sich fyear
local bias sprate ff48 lnat cash2at profit2at bklev mb1 fcf2at ///
           cfvol firmage nlosses tang_a sale_a roa inv_a ior abret stkvol stkpct optpct ///
           wcap_a re_a
local extradj
local depvar

** (1.2) Generate dependent variables

** Calculate correspondent cross-cds differences 
** of payout variables (`payoutvar'):
foreach v of local payoutvar {
** if the payout variable is a growth rate, 
** (r(t+3)+r(t+2))/2 -(r(t-1)+r(t-2))/2 is calculated;
	if regexm("`v'","_growth") {
		gendepvar growth 2 `v'
		local depvar `depvar' `v'_dif_2
	}
** if the payout variable is a quantity,
** (x(t+3)+x(t+2)+x(t+1))/3 -(x(t-1)+x(t-2)+x(t-3))/2 is calculated.
	else {
		gendepvar quantity 3 `v'
		local depvar `depvar' `v'_dif_3
	}
** this is a good correspondence since theoretically r(t) = x(t)-x(t-1);
** in both cases time t is purposely excluded;
** we use the "factory function" gendepvar to emcompass all situations;
** more about the implementing details, refer to factory.do.

** the name of generated dependent variables 
** are then stored in the local macro depvar.  
}

** (1.3) Generate treatment variable for nnmatch

** Assign the samples into treatment group and control group.

** The variable cdsactive (`cdsvar') is not the proper treatment variable,
** but we use it to calculate the correct treatment variable:

** We only assign the samples which is at the fyear when cds happened to the treatment group;
** all samples whose cdsactive==1 but at other fyear will be excluded;
** all samples whose cdsactive==0 will be retained in control group.

** We name the newly generated treatment variable "iscds":

assigntreat `cdsvar' iscds
drop if iscds == .

** we use the "factory function" assigntreat to achieve the above jobs.

** (1.4) Generate acustomized adjustment variable for nnmatch

** Calculate  before-cds growth of payout variables (`payoutvar'):

foreach v of local payoutvar {
** x(t-1)-x(t-2) is calculated
	generate  `v'_dif = D.L.`v'
	local extradj `extradj' `v'_dif
** the name of generated adjustment variables 
** are then stored in the local macro extradj. 
}

/******************************************************
	STEP (2): nnmatch
******************************************************/

** (2.1) strict match exactness to control macro effect 

** copy extradj in order not to contaminate it
** extradj will be used repeatedly
local temp `extradj'
** tokenize `tempt' to retrieve its contents one by one,
** its meaning becomes clear in the following `1' and macro shift operation
	tokenize `temp'

foreach v of local depvar {
	display _newline "exact match:"
	display _newline "The Dependent variable is: `v'"	
** the nearest-neighbor matching.	
	nnmatch `v' iscds `cdsdeterm' , tc(att) exact(`varlist_exact') biasadj(`bias' `1')
** pop the first token in `temp'	
	macro shift
}

** (2.2) no exact match required, set m = 1

local temp `extradj'
tokenize `temp'

foreach v of local depvar {
	display _newline "non-exact match, set m = 1:"
	display _newline "The Dependent variable is: `v'"
	nnmatch `v' iscds `cdsdeterm' , m(1) tc(att) biasadj(`bias' `1')
	macro shift
}

** (2.3) no exact match required, set m = 4

local temp `extradj'
tokenize `temp'

foreach v of local depvar {
	display _newline "non-exact match, set m = 4:"
	display _newline "The Dependent variable is: `v'"
	nnmatch `v' iscds `cdsdeterm' , m(4) tc(att) biasadj(`bias' `1')
	macro shift
}


** caution, the option robus(1) makes the calculation spending unlimited time

/* 
foreach v of local depvar {
	nnmatch `v' iscds `cdsdeterm' , tc(att) robust(1) exact(`varlist_exact') biasadj(`bias')
}
*/