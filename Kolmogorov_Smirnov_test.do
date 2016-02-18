
clear

cd C:\Users\Xue\workspace\econometric_stata\

/* 

webuse ksxmpl

save raw_data\ksxmpl

*/
   
use raw_data\ksxmpl

summ x

** one-sample test

ksmirnov x = normal((x - r(mean)) / r(sd))

program thenormal
	quietly summ `1'
	tempvar std
	tempvar nn
	quietly generate `std' = (`1' - r(mean)) / r(sd)
	tab `std'
	quietly generate `nn' = normal(`std')
	tab `nn'
	drop `std'
	drop `nn'
end





