ko       = require 'ko'
defLocal = require 'locales/en_US'
Base     = require 'libs/base_mvm'
Login    = require './login'
Area     = require './area'

class Common extends Base
	constructor : ->
		super

		@isAuthorized  = ko.observable no
		@locale        = ko.observable defLocal

		@login         = new Login
		@area          = new Area
		
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

module.exports = Common