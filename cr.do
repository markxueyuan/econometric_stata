clear

local projectpath C:\Users\Xue\workspace\econometric_stata\
local datapath .\raw_data

cd `projectpath'
   
** use raw_data\cr_data_later.dta

/*****************************************************
	STEP (0): Prepare CPI data
******************************************************/

/*  Using freduse to download time-series data from the Federal Reserve

	which is actually downloaded manually from website and read from a local file (the file option)
*/

freduse `datapath'\CPIAUCSL, file clear



rename CPIAUCSL cpi

/* mofd( e d )
Description: the e m monthly date (months since 1960m1) containing date e d
Domain e d : %td dates 01jan0100 to 31dec9999 (integers − 679,350 to 2,936,549)
Range: %tm dates 0100m1 to 9999m12 (integers − 22,320 to 96,479) */


g mdate = mofd(daten)
format mdate %tm
keep if mdate > ym(1990,12)

*** Rebase CPI so its base is 2002;

quietly summarize cpi if year(daten)==2002
replace cpi = cpi/r(mean)

*** Housekeeping
keep mdate cpi

*** Save to tempfile;
tempfile temp_cpi
save "`temp_cpi'"

/******************************************************
	STEP (1): Prepare Ratings data
******************************************************/
*** Get ratings data
use gvkey datadate splticrm using "`datapath'\adsprate.dta", clear
** tab splticrm

*** Get monthly date

gen mdate=mofd(datadate)

*** Generate numeric rating without the plus/minus;
gen sprate	= 1*(splticrm == "AAA") ///
			+ 2*(splticrm == "AA+" | splticrm == "AA" | splticrm == "AA-") ///
			+ 3*(splticrm == "A+" | splticrm == "A" | splticrm == "A-") ///
			+ 4*(splticrm == "BBB+" | splticrm == "BBB" | splticrm == "BBB-") ///
			+ 5*(splticrm == "BB+" | splticrm == "BB" | splticrm == "BB-") ///
			+ 6*(splticrm == "B+" | splticrm == "B" | splticrm == "B-") ///
			+ 7*strmatch(splticrm, "C*") ///
			+ 8*inlist(splticrm,"D","N.M.","SD","Suspended")
			
gen cr_ig = inlist(sprate,1,2,3,4)
gen cr_sg = inlist(sprate,5,6,7)|splticrm=="D"

gen has_cr = ~(inlist(splticrm, "N.M.","SD","Suspended",""))


g year = year(datadate)
rename datadate crdate
    ** SCREEN: Get rid of multiple observations within a year
    ** 		 by keeping only the last observation in a year;
    ** bysort gvkey year: keep if _n == _N;

	
tempfile rat
save `rat'


/********************************************************
	STEP (2): Prepare Compustat data
*********************************************************/
** Set the variables to be extracted;


local idvars "gvkey fyear datadate indfmt datafmt popsrc consol fic conm compst"

** the = sign is a most in the following assigning equation
local finvars = "emp at xlr sich ib dp ppent ppegt dlc dltt oibdp oiadp pstkl ceq " ///
			+ "txditc pi sale re act lct csho prcc_f xrd che capx txdb"
		
use	`idvars' `finvars' /// 
		using "`datapath'\funda.dta" ///				
	  	if 	(indfmt=="INDL") ///
		&   (datafmt=="STD") ///
		&	(popsrc=="D") ///
		&	(consol=="C") ///					
		& 	inrange(fyear,1991,2013) ///		
		&  	(gvkey != "") ///					
		&  	(fyear != .) ///
		&   (fic=="USA") ///
		& 	~(sich  >= 6000 & sich <= 6999) ///
		&   (at>0 & at<.) ///    
		&   (sale>0 & sale<.) ///
		&   (emp>0 & emp<.) ///
   , clear
   
** Housekeeping;   
drop indfmt datafmt popsrc consol fic

*** May have duplicates of firm-fyear due to change of fiscal years, keep most recent;
gsort gvkey fyear -datadate
duplicates drop gvkey fyear, force

*** Monthly date;
gen mdate = mofd(datadate)

*** Merge with CPI data;
merge m:1 mdate using "`temp_cpi'"
keep if _merge == 3
drop _merge

** Deflate all variables;
local vars = "at ppent xlr capx ib dp oiadp prcc_f ceq txdb dlc dltt oibdp " ///
            + "che sale re act lct ppegt"

foreach v of local vars {
	replace `v' = `v' / cpi
}


** Merge with credit rating file;
g year = year(datadate)
joinby gvkey year using `rat', unmatched(both) 
drop if _merge == 2
drop _merge // why not directly unmatched(master)

** Keep the most recent rating before datadate;
drop if crdate > datadate & crdate < .

bysort gvkey datadate (crdate): keep if _n==_N

** Further mark obs. without SP rating;
replace has_cr = 0 if has_cr==.
replace sprate = 0 if sprate==.

** Add employment footnote;
merge 1:1 gvkey datadate using "`datapath'\emp_fn"
drop if _merge==2
drop _merge

** Claim panel data;
destring gvkey, replace
tsset gvkey fyear

** Define dependent variables;
replace emp			= emp*1000                                // Original emp is in thousands
g   log_emp 		= log(emp)                                
g   emp_dif			= emp - L.emp
g   emp_growth  	= emp_dif/(L.emp)
g   emp_growth_ppe	= emp_dif/(L.ppent)
g   emp_growth_at	= emp_dif/(L.at)
g   sym_emp_growth 	= emp_dif/(0.5*(emp+L.emp))
g   D_parttime 		= emp_fn=="IE"                             // Zero denotes missing as well
g   log_wage 		= log(xlr)	
g   inv_k 			= capx/(L.ppent)
g   inv_a 			= capx/(L.at)

** Define firm controls;
g   loga    	= log(at)	
g 	cf			= (ib + dp)									// Cash flow
g 	cf_k		= cf / L.ppent   								// Cash flow / capital(t)
g 	cf_a		= cf / L.at      								// Cash flow / assets(t)
g   roa     	= oiadp / L.at
g	mb 			= ((prcc_f * csho) + at - ceq - txdb) / at	    // market-to-book
g	td			= dlc + dltt								    // Total Debt
g	bl			= td / at									    // Book leverage
g	ml			= td / (td + (prcc_f * csho))				    // Market leverage
g	prof_a		= oibdp / L.at								    // Profitability
g	tang_a		= ppent / L.at							        // Tangibility
g   cash    	= che / at                                     // Cash 
g   sale_a      = sale / at                                    // Sale
g	me 			= prcc_f * csho                                // Market cap
g   logme		= log(me)
g   chg_ppe 	= (ppegt-L.ppegt) / (L.ppegt)               	// Gross fixed asset change
g   at_emp      = at / emp                                     // Assets per employee ($MM)
g   sgr 		= sale / L.sale                                // Sale growth
g   atmat    	= ppegt / dp                                   // Asset maturity
g   chg_inv		= (capx-L.capx) / L.capx                       // Percentage change in investment
g	ul_zscore	= (3.3 * pi ///
				+ sale ///
				+ 1.4 * re ///
				+ 1.2 * (act - lct)) / at 						// Altman's unlevered Z-score
g   zscore		= 3.3 * oiadp / at ///
				+ 0.99*sale / at ///
				+ 1.4 * re / at ///
				+ 0.6 * prcc_f * csho / td ///
				+ 1.2 * (act - lct) / at						// Altman's Z-score;	 
	  

** Only keep the variables were going to use to reduce dataset size and speed things up;
local vlist = "at loga cf cf_k cf_a sale_a roa mb bl ml prof_a tang_a cash me logme chg_ppe " ///
 + "at_emp sgr atmat chg_inv ul_zscore zscore sprate cr_ig cr_sg has_cr"

** D_parttime does not exist, so we capture
capture keep gvkey datadate fyear sich compst ///
 emp log_emp emp_growth emp_growth_ppe emp_growth_at sym_emp_growth D_parttime ///
 log_wage xlr inv_k inv_a ///
			`vlist'	
		
** Save;
tempfile temp_comp
save "`temp_comp'"	
/********************************************************
 End of STEP (2): Prepare Compustat data
*********************************************************/


/********************************************************
	STEP (3): Prepare CDS data and merge with Compustat
*********************************************************/	
** Load CDS data;
import delim using "`work'\firstcds.csv",  varnames(1) clear;

** Convert dates to numerical;
g temp = date(firstcds,"DMY",2010) // is 2010 the right choice?
format temp %td
drop firstcds
rename temp firstcds
	
** Choose to use gvkey;
** Check with Dragon;	
destring gvkey, replace force
drop if missing(gvkey)

** For three dup gvkey, use earlier date;
bysort gvkey (firstcds): keep if _n==1

** Housekeeping;
keep gvkey firstcds
distinct gvkey // which package does distinct come from?

** Merge with firm variables;
merge 1:m gvkey using "`temp_comp'"
drop if _merge==1

** Mark firms with CDS traded at any point during our sample period;
g cdsfirm = _merge==3   
drop _merge
	
** Create a dummy that equals one after the inception of the firm's CDS trading 
** and zero prior to it;
** It is always zero for non-CDS firms;
g cdsactive = 0
replace cdsactive = 1 if datadate>=firstcds

** Output;
save "`datapath'\cr_data.dta", replace