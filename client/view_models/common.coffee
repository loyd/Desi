ko               = require 'ko'
ls               = require 'libs/local_storage'
dot              = require 'dot'
JsZip            = require 'jszip'
profileSpec      = require 'models/profile'
Synchronizer     = require 'libs/synchronizer'
defLocal         = require 'locales/en_US'
defTemplates     = require 'templates'

BaseViewModel    = require 'libs/base_view_model'
DiagramViewModel = require './class_diagram'

dot.templateSettings['strip'] = off

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

		@generationCandidate = ko.observable null

		@templates       = defTemplates
		@templateIndex   = ko.observable null
		@templateContent = ko.observable null
		@templateIsInvalid = ko.observable no

		@templateIndex.subscribe (index) =>
			@templateContent @templates[index].content

		@templateIndex 0
		@title = ko.observable 'Desi'

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
			@title name
			@sectionTemplate "#{name}-tmpl"

		'generation' : ->
			diag = @chosenDiagram() ? @generationCandidate()
			if diag
				@navigate "generation/#{diag.title()}"
			else
				@navigate ''

		'generation/:title' : (title) ->
			@generationCandidate @diagrams().scan (item) -> item.title() == title
			do @toggleSidebar unless @sidebarIsClosed()
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

	@computed \
	templateFunction : ->
		return null if @templateIsInvalid()

		try
			fn = dot.template @templateContent()
		catch error
			return null

		fn

	@delegate('click', '#generation .btn-generate-and-download') ->
		return unless @templateFunction()
		model = ls.expand @generationCandidate().sync.id
		return unless model

		transformVisibility = (mem) ->
			mem.visibility = switch mem.visibility
				when '+' then 'public'
				when '-' then 'private'
				when '#' then 'protected'
				when '~' then 'package'
				when '/' then 'derived'

		essTable = {}
		for ess in model.essentials
			essTable[ess.__id] = ess
			ess.associations = []
			ess.aggregations = []
			ess.compositions = []
			ess.generalizations = []
			ess.realizations = []
			ess.dependencies = []

			transformVisibility attr for attr in ess.attributes
			transformVisibility oper for oper in ess.operations

		for rel in model.relationships
			from = essTable[rel.fromEssential]
			to   = essTable[rel.toEssential]
			if rel.type == 'generalization'
				from.parent = to
			
			if rel.type == 'dependency'
				from.dependencies.push to
			else
				from["#{rel.type}s"].push to

		try
			for ess in model.essentials
				ess.strView = @templateFunction() ess
			
		catch error
			@templateIsInvalid yes
			sbcr = @templateContent.subscribe =>
				@templateIsInvalid no
				do sbcr.despose
			return

		zip = new JsZip
		ext = @templates[@templateIndex()].ext
		for ess in model.essentials
			zip.file "#{ess.name}#{ext}", ess.strView.trim()

		if window.URL?.createObjectURL
			blob = zip.generate type : "blob"
			link = document.createElement 'a'
			link.href = window.URL.createObjectURL blob
			link.download = "#{model.title}.zip"
			link.click()
		else
			content = zip.generate()
			location.href = 'data:application/zip;base64,' + content

		return

	@delegate('click', '#lookup .btn-create-diagram') ->
		do @createDiagram

	@delegate('click', '#lookup .btn-remove-diagram') (item) ->
		if item is @generationCandidate()
			@generationCandidate null

		@removeDiagram item.title()

	@delegate('click', '#lookup .btn-edit-diagram') (item) ->
		@navigate "edit/#{item.title()}"

	@delegate('click', '#lookup .btn-close-diagram') (item) ->
		@closeDiagram item.title()

	@delegate('click', '#lookup .btn-rename-diagram') (item) ->
		item.isRenamed yes

	@delegate('click', '#lookup .btn-generate-code') (item) ->
		@generationCandidate item
		@navigate 'generation'

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