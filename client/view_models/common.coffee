ko = require 'ko'
defLocal = require 'locales/en_US'

LoginViewModel = require './login'

class CommonViewModel
	constructor : ->
		@isAuthorized = ko.observable no
		@locale       = ko.observable defLocal
		@login        = new LoginViewModel
		@activeSection = ko.observable @login

	toggleSidebar : =>

module.exports = CommonViewModel