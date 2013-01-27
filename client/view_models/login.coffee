BaseViewModel = require 'libs/base_view_model'

class LoginViewModel extends BaseViewModel
	sectionTmpl : 'login-tmpl'

	constructor : ->
		#...
		
		super

module.exports = LoginViewModel