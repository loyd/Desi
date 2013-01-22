ko             = require 'ko'
defLocal       = require 'locales/en_US'
BaseViewModel  = require 'libs/base_view_model'
LoginViewModel = require './login'
AreaViewModel  = require './area'

class CommonViewModel extends BaseViewModel
	constructor : ->
		super

		@isAuthorized  = ko.observable no
		@locale        = ko.observable defLocal

		@login         = new LoginViewModel
		@area          = new AreaViewModel
		
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