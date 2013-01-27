BaseViewModel = require 'libs/base_view_model'

class SignupViewModel extends BaseViewModel
	sectionTmpl : 'signup-tmpl'

	constructor : ->
		#...
		
		super

module.exports = SignupViewModel