#delimit cr
clear

** set the macro names for different regression methods using in cmp model
cmp setup


** load example data
webuse laborsup
gen byte anykids = kids > 0

************************** the command for Tobit on Probit *************************************************

* this model test if the status of having kids influence female's income using simultaneous linear system combining Tobit and Probit


cmp (fem_inc = anykids other_inc male_educ) (anykids = other_inc male_educ), ind("cond(fem_inc>10,$cmp_cont,$cmp_left)" $cmp_probit)


************************** The validity of this model ********************************

** In http://www.stata.com/statalist/archive/2007-10/msg00646.html , it says:

**            "So for example, you could regress a censored variable on two
**          endogenous variables, one binary and one continuous and uncensored, each
**          instrumented with other variables."

** Which means it is valid to build the second stage Tobit model (left or right censored) on the basis 
** of the first stage Probit (binary dependent variable) model using cmp in practice.

** I don't know if cmp solves your concerns mentioned in the email; I need to take a look at the implemented detail of cmp.
** Is it possible to run your model as latent variable model, as the last past of the do file shows?

************************* The illustration of the syntax *****************************

** ind() option indicates what kind of regression is run for the correspondent equation.
** $cmp_cont stands for the normal regression; $cmp_left stands for left censored regression; $cmp_probit stands for Probit models
** In our example the first item in the ind() corresponds to the first equation, which is a Tobit regression, 
** the second item corresponds to the second euqation, which is a Probit regression

************************ Other issues ***********************************************

** the algorithm may not converge



** ********************** Alternatives? ************************************************

** It is also possible to run a model of latent variables. Latent variables are indicated by adding # suffix.

cmp (eq1: fem_inc = equ2# other_inc male_educ) (equ2: anykids = other_inc male_educ), ind("cond(fem_inc>10,$cmp_cont,$cmp_left)" $cmp_probit)

** or equivalently

cmp (fem_inc = anykids# other_inc male_educ) (anykids = other_inc male_educ), ind("cond(fem_inc>10,$cmp_cont,$cmp_left)" $cmp_probit)
