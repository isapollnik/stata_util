cap prog drop assertapprox
program define assertapprox
	// Parse expression and tolerance
	syntax anything(equalok name=expr), TOL(real) [if]
	
	// Split expression on "="
	gettoken lhs rest : expr, parse("==")
	gettoken eq rhs : rest, parse("==")
	
	// Validation
	if "`eq'"!="==" {
		di as error "expression must be of the form <lhs> == <rhs>"
		exit 198
	}
	
	assert ///
		((`rhs' !=0 & (abs(`lhs' - `rhs') / `rhs') <= `tol') | ///
		(`rhs' == 0 & (abs(`lhs')<=`tol'))) `if'
	
end
