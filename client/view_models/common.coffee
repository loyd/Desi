ko              = require 'ko'
ls              = require 'libs/local_storage'
profileSpec     = require 'models/profile'
Synchronizer    = require 'libs/synchronizer'
defLocal        = require 'locales/en_US'

BaseViewModel   = require 'libs/base_view_model'
AreaViewModel   = require './area'
LoginViewModel  = require './login'
LookupViewModel = require './lookup'
SignupViewModel = require './signup'

class CommonViewModel extends BaseViewModel
	constructor : ->
		super

		@isAuthorized    = ko.observable ls.has('profile')
		@sidebarIsClosed = ko.observable yes
		@locale          = ko.observable defLocal

		if @isAuthorized()
			do @authorize

		@login  = new LoginViewModel
		@signup = new SignupViewModel
		
		@activeSection = ko.observable null
	
	authorize : ->
		profileSync = new Synchronizer profileSpec, ls('profile')
		diagramsSync = profileSync.concretize 'diagrams'

		@area   = new AreaViewModel diagramsSync
		@lookup = new LookupViewModel diagramsSync
		
		@account = null
		@generation = null
		@exportation = null
		@share = null

	deauthorize : ->
		@area   = null
		@lookup = null

	toggleSidebar : =>
		val = @sidebarIsClosed()
		@sidebarIsClosed !val

	toRoot : ->
		@navigate(if @isAuthorized() then 'lookup' else 'login')

	toSection : (name) ->
		@activeSection this[name]

	@route {
		''                     : 'toRoot'
		':section, :section/*' : 'toSection'
	}

module.exports = CommonViewModel