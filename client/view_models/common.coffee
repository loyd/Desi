ko             = require 'ko'
defLocal       = require 'locales/en_US'
BaseViewModel  = require 'libs/base_view_model'
LoginViewModel = require './login'

class CommonViewModel extends BaseViewModel
	constructor : ->
		super

		@isAuthorized = ko.observable no
		@locale       = ko.observable defLocal
		@login        = new LoginViewModel
		@activeSection = ko.observable @login

	toggleSidebar : =>

	toRoot : ->
		@navigate(if @isAuthorized() then 'workspace' else 'login')

	toSection : (name) ->
		@activeSection this[name]

	@route {
		''                     : 'toRoot'
		':section, :section/*' : 'toSection'
	}

module.exports = CommonViewModel