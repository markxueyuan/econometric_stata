program assigntreat
	tempvar istreat
	generate `istreat' = .
	replace `istreat' = 1 if `1' == 1 & L.`1' == 0
	replace `istreat' = 0 if `1' == 0
	generate `2' = `istreat'
end

** assigntreat cdsactive iscds


program difavg, sclass
	local a 0.0
	local b 0.0
	forvalues i = 1(1)`1' {
		local a `a' + F`i'.`2'
		local b `b' + L`i'.`3'
	}
	local a (`a')
	local b (`b')
	local c `a' / `1' - `b' / `1'
	display "The calculated difference is:" _newline "`c';"
	sreturn local dif `c'
end


program gendifavg
	difavg `1' `2' `3'
	generate `4' = `s(dif)'
	display "named as `4'."
end

** gendifavg 2 F.emp_growth emp_growth emp_growth_dif_2

program gendepvar
	args type span var
	local newvar `var'_dif_`span'
	if "`type'" == "growth" {
		gendifavg `span' F.`var' `var' `newvar'
	}
	else if "`type'" == "quantity" {
		gendifavg `span' `var' `var' `newvar'
	}
end

** gendepvar growth 2 emp_growth_at
** gendepvar quantity 3 emp

