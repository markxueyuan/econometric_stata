#delimit cr
capture log close
capture program drop _all
estimates drop _all
clear all


set more off
set rmsg on

set min_memory 500m
set max_memory 1g

global projectpath C:\Users\Xue\workspace\econometric_stata\
global datapath .\raw_data

cd $projectpath

log using mylog , replace text

/*******************************************************
                   
				   Load Data
				   
*******************************************************/

** import delimited "$datapath\fisd_matched.csv", clear

** save "$datapath\fisd_matched.dta", replace


use "$datapath\fisd_matched.dta", clear


/*******************************************************
                   
				   Dependent Variables
				   
*******************************************************/

** dependent variables
local dependents offering_yield treasury_spread


/******************************************************

          Macros for Assembling  Treatment Variables
		  
*******************************************************/

** news sentiments and news count
local sentiments ess aes
local stats mean median
local days 5 10 15 20 25 30 45 60
local news_type pr npr all


/******************************************************

                Control Variables
		  
*******************************************************/




** maturity 
gen maturity_level = (date(maturity, "DMY") - date(offering_date, "DMY")) / 365
label variable maturity_level "Maturity Years"
local maturity_level maturity_level

** rating
label variable rating "Ratings"
local rating rating

/*

Calculatiing Method:

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


** all control variables

local control_variable = "`maturity_level' `rating' `offering_amt' `convertible' " + ///
        "`private_placement' `rule_415_reg' `secured' `callable' `putable' `crisis'"
				  
				  
/******************************************************

                Samples Selection
		  
*******************************************************/

keep if inlist(bond_type,"CDEB","CMTN")	
drop if yankee == 1
drop if permno_new == .

/******************************************************

                Cluster Standord Errors
		  
*******************************************************/

				  
** firm-year 			  

bysort permno_new issue_year : generate firm_year = 1 if _n == 1
replace firm_year = sum(firm_year)
label variable firm_year "Firm Year"
local firm_year firm_year




/******************************************************

         An illustration of one speical case:
 Effects of 30 days median of ESS on offering yields
 
*******************************************************/


regress offering_yield  ///
        ess_median_b30_pr ess_count_b30_pr ///
		maturity_level rating offering_amt convertible private_placement ///
		rule_415_reg secured callable putable crisis ///
		, vce(cluster firm_year)
		

/******************************************************

                Regressions and Outputs
 
*******************************************************/


** preparing function

program return_label, rclass
	if "`1'" == "ess" {
		return local `1' "ESS"
	} 
	else if "`1'" == "aes" {
		return local `1' "AES"
	}
	else if "`1'" == "mean" {
		return local `1' "Mean"
	}
	else if "`1'" == "median" {
		return local `1' "Median"
	}
	else if "`1'" == "pr" {
		return local `1' "Press Release"
	}
	else if "`1'" == "npr" {
		return local `1' "Non Press Release"
	}
	else if "`1'" == "all" {
		return local `1' "All Types"
	}
	else if "`1'" == "offering_yield" {
		return local `1' "Offering Yield"
	}
	else if "`1'" == "treasury_spread" {
		return local `1' "Treasury Spread"
	}
end

foreach dp of local dependents {
	
	foreach d of local days {
		
		foreach nt of local news_type {
		
			local ct "ess_count_b`d'_`nt'"
			label variable `ct' "Numbers of News"
		
			local sentis
		
			foreach st of local stats {
				
				foreach ss of local sentiments {
					
					return_label `ss'
					local rss `r(`ss')'
					return_label `st'
					local rst `r(`st')'
					local senti "`ss'_`st'_b`d'_`nt'"
					label variable `senti' "`rst' of `rss'"
					local sentis `sentis' `senti'
					
			** regression		
					eststo: quietly ///
							regress `dp' `senti' `ct' `control_variable' ,vce(cluster `firm_year')
				}
			}
		
			return_label `nt'
			local rnt `r(`nt')'
			return_label `dp'
			local rdp `r(`dp')'
			label variable `dp' "`rdp'"
		
			** output
			esttab, ar2 label beta se ///
					title("Effects of News Sentiments on `rdp' (`d' days, `rnt')") ///
					order(`sentis' `ct' `control_variable') ///
					star(* 0.10 ** 0.05 *** 0.01) ///
					addnote("Source: xxxxxxxx") ///

				
			eststo clear
		
		}
	}
}
