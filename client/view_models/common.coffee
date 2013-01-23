ko              = require 'ko'
ls              = require 'libs/local_storage'
defLocal        = require 'locales/en_US'
BaseViewModel   = require 'libs/base_view_model'
LoginViewModel  = require './login'
SignupViewModel = require './signup'
AreaViewModel   = require './area'

class CommonViewModel extends BaseViewModel
	constructor : ->
		super

		@isAuthorized  = ko.observable ls.has('profile')
		@locale        = ko.observable defLocal

		@area          = new AreaViewModel
		@login         = new LoginViewModel
		@signup        = new SignupViewModel
		
		@activeSection = ko.observable null

	toggleSidebar : =>

	toRoot : ->
		@navigate(if @isAuthorized() then 'area' else 'login')

	toSection : (name) ->
		@activeSection this[name]

	@route {
		''                     : 'toRoot'
		':section, :section/*' : 'toSection'
	}

module.exports = CommonViewModel