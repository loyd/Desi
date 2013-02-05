ko               = require 'ko'
ls               = require 'libs/local_storage'
profileSpec      = require 'models/profile'
Synchronizer     = require 'libs/synchronizer'
defLocal         = require 'locales/en_US'

BaseViewModel    = require 'libs/base_view_model'
DiagramViewModel = require './class_diagram'

class CommonViewModel extends BaseViewModel
	constructor : ->
		@isAuthorized    = ko.observable ls.has('profile')
		@sidebarIsClosed = ko.observable yes
		@locale          = ko.observable defLocal

		if @isAuthorized()
			do @authorize

		@sectionTemplate = ko.observable null
		@openDiagrams    = ko.observableArray()
		@chosenDiagram   = ko.observable null

		super
	
	reqAuth = (propName) -> ->
		@[propName] arguments... if @isAuthorized()

	@route {
		''            : 'toRoot'
		'edit/:title' : {
			in : (title) ->
				@openDiagram title
				do @toggleSidebar unless @sidebarIsClosed()
			out : ->
				do @chosenDiagram().data.stopEditing
				@chosenDiagram null
		}
		':section, :section/*' : (name) ->
			@sectionTemplate "#{name}-tmpl"
	}

	openDiagram : (title) ->
		res = @diagrams().scan (item) ->
			item.title() == title

		unless res
			@navigate ''
		else
			unless res.isOpen()
				do res.open
				@openDiagrams.push res

			@chosenDiagram()?.data.stopEditing()
			@chosenDiagram res
			do res.data.startEditing

		return

	closeDiagram : (title) ->
		res = @openDiagrams.remove (item) ->
			item.title() == title

		do res[0].close if res.length

		return

	removeDiagram : (title) ->
		@closeDiagram title
		@diagrams.remove (item) ->
			item.title() == title

		return

	createDiagram : ->
		sync = new Synchronizer @diagramsSync.spec.item
		diag = new DiagramItemViewModel sync
		date = new Date
		diag.lastModifiedInMs +date + date.getTimezoneOffset() * 1000
		diag.title diag.title() + +date
		@diagrams.push diag

	authorize : ->
		@profileSync = new Synchronizer profileSpec, ls('profile')
		@diagramsSync = @profileSync.concretize 'diagrams'

		@diagrams = @diagramsSync.observer
			classAdapter : DiagramItemViewModel
		
		@account = null
		@generation = null
		@exportation = null
		@share = null

	deauthorize : ->

	toggleSidebar : =>
		val = @sidebarIsClosed()
		@sidebarIsClosed !val

	toRoot : ->
		@navigate(if @isAuthorized() then 'lookup' else 'login')

	@delegate('click', '#lookup .btn-create-diagram') ->
		do @createDiagram

	@delegate('click', '#lookup .btn-remove-diagram') (item) ->
		@removeDiagram item.title()

	@delegate('click', '#lookup .btn-edit-diagram') (item) ->
		@navigate "edit/#{item.title()}"

	@delegate('click', '#lookup .btn-close-diagram') (item) ->
		@closeDiagram item.title()

	@delegate('click', '#lookup .btn-rename-diagram') (item) ->
		item.isRenamed yes

	oldActived = null
	@delegate('click', '#lookup .diagram-item') (item) ->
		oldActived?.isActive no
		oldActived = item
		item.isActive yes

class DiagramItemViewModel extends BaseViewModel
	constructor : (@sync) ->
		@title            = sync.observer 'title'
		@lastModifiedInMs = sync.observer 'lastModified'

		@isRenamed = ko.observable no
		@isOpen    = ko.observable no
		@isActive  = ko.observable no

		super

	open : ->
		@data = new DiagramViewModel @sync
		@isOpen yes

	close : ->
		@data = null
		@isOpen no

	@computed \
	lastModified : ->
		d = new Date(@lastModifiedInMs() - new Date().getTimezoneOffset() * 1000)
		"#{d.toLocaleDateString()} #{d.toLocaleTimeString()}"

module.exports = CommonViewModel