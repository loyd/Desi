ko           = require 'ko'
ls           = require 'libs/local_storage'
dot          = require 'dot'
share        = require 'share'
JsZip        = require 'jszip'
{jsSHA}      = require 'jssha'
profileSpec  = require 'models/profile'
diagramSpec  = require 'models/class_diagram'
Synchronizer = require 'libs/synchronizer'
defLocal     = require 'locales/en_US'
defTemplates = require 'templates'

BaseViewModel    = require 'libs/base_view_model'
DiagramViewModel = require './class_diagram'

dot.templateSettings['strip'] = off
authField = null

class CommonViewModel extends BaseViewModel
	constructor : ->
		@isAuthorized    = ko.observable no#ls.has('remember')
		@sidebarIsOpen   = ko.observable no
		@locale          = ko.observable defLocal

		# if @isAuthorized()
		# 	do @localAuthorize

		@invalidLogin    = ko.observable no
		@invalidPassword = ko.observable no
		@inputLogin      = ko.observable ''
		@inputPassword   = ko.observable ''
		@inputPassword2  = ko.observable ''

		@sectionTemplate = ko.observable null
		@openDiagrams    = ko.observableArray()
		@chosenDiagram   = ko.observable null

		@candidate = ko.observable null

		@templates       = defTemplates
		@templateIndex   = ko.observable null
		@templateContent = ko.observable null
		@templateIsInvalid = ko.observable no

		@templateIndex.subscribe (index) =>
			@templateContent @templates[index].content

		@templateIndex 0
		@title = ko.observable 'Desi'

		@online = ko.observable navigator.onLine
		addEventListener 'online',  (=> @online yes), off
		addEventListener 'offline', (=> @online no),  off

		@remember = ko.observable yes
		addEventListener 'unload', =>
			do @deauthorize unless @remember()
		, off

		if ls.has 'remember'
			data = ls.expand ls('remember')
			@inputLogin data.login
			@inputPassword data.psw
			do @authorize

		super
	
	reqAuth = (propName) -> ->
		@[propName] arguments... if @isAuthorized()

	@route {
		''            : 'toRoot'
		'edit/:title' : {
			in : (title) ->
				@openDiagram title
				do @toggleSidebar if @sidebarIsOpen()
			out : ->
				do @chosenDiagram().data?.stopEditing
				@chosenDiagram null
		}
		
		':section, :section/*' : (name) ->
			if @isAuthorized() || name in ['login', 'signup']
				@title name
				@sectionTemplate "#{name}-tmpl"
			else
				@navigate 'login'

		'logout' : ->
			xhr = new XMLHttpRequest
			xhr.open 'GET', '/logout', yes
			xhr.onreadystatechange = =>
				return if xhr.readyState != 4
				do @deauthorize if xhr.status == 200

			xhr.send null

		'generation' : ->
			diag = @chosenDiagram() ? @candidate()
			if diag
				@navigate "generation/#{diag.title()}"
			else
				@navigate ''

		'generation/:title' : (title) ->
			@openDiagram title, (res) =>
				return @navigate '' unless res
				@candidate res
				do @toggleSidebar if @sidebarIsOpen()

		'share, share/*' : ->
			unless @candidate()
				if @chosenDiagram()
					@candidate @chosenDiagram()
				else
					@navigate ''

		'remote' : -> @navigate ''
		'remote/:id' : (id) ->
			diag = @createDiagram()
			diag.id id
			@navigate 'lookup'
	}

	openDiagram : (title, cb) ->
		res = @diagrams().scan (item) ->
			item.title() == title

		fire = =>
			@chosenDiagram()?.data?.stopEditing()
			@chosenDiagram res
			do res.data.startEditing
			cb? res

		unless res
			@navigate ''
		else
			if res.isOpen()
				do fire
			else res.open =>
				@openDiagrams.push res
				do fire

		return

	closeDiagram : (title) ->
		res = @openDiagrams.remove (item) ->
			item.title() == title

		do res[0].close if res.length

		return

	removeDiagram : (title) ->
		@closeDiagram title
		@diagrams.delete (item) ->
			item.title() == title

		return

	createDiagram : ->
		sync = new Synchronizer profileSpec.data.diagrams.item
		diag = new DiagramItemViewModel sync
		date = new Date
		now  = Date.now()
		diag.lastModifiedInMs now + date.getTimezoneOffset() * 1000
		diag.title diag.title() + now

		profileTop = ls.expand ls('profile'), 0
		profileId  = ls profileTop['login']
		diag.id calcSHA1 profileId + now
		@diagrams.push diag
		diag

	authorize : ->
		do ls.clear

		makeSync = (key) =>
			@profileSync = new Synchronizer profileSpec, key
			do @profileSync.markAsMaster
			@diagrams = @profileSync.observer 'diagrams',
				classAdapter : DiagramItemViewModel
			ls 'profile', key

			ptrId = @profileSync.observer 'freePtrId'
			login = @profileSync.observer 'login'
			Synchronizer.registerPidGetter =>
				freePtr = ptrId()
				ptrId +freePtr + 1
				"#{login()}:#{freePtr}"

		work = (doc) =>
			@profileSync.attach doc
			@isAuthorized yes
			if @remember()
				ls 'remember', ls.allocate { login, psw }
			@navigate 'lookup'

		[login, psw] = [@inputLogin(), @inputPassword()]
		authField = "#{login}:#{calcSHA1 psw}"
		share.open "profile:#{login}", 'json', {
			authentication : authField
		}, (err, doc) =>
			return if err?

			if r = doc.get()
				makeSync ls.allocate r
				(-> work doc).defer()
			else
				key = ls.allocate { freePtrId : 1, login, diagrams : [] }
				makeSync key
				doc.set ls.expand(@profileSync.id), -> work doc

	localAuthorize : ->

	deauthorize : ->
		do @profileSync.doc.close
		for diag in @openDiagrams()
			do diag.close
		do ls.clear
		@isAuthorized no
		@navigate 'login'

	@delegate('click', '#btn-sidebar') \
	toggleSidebar : ->
		unless @isAuthorized()
			return @sidebarIsOpen no

		val = @sidebarIsOpen()
		@sidebarIsOpen !val

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

	@delegate('click', '#generation .btn-generate-and-download') (e, event) ->
		return unless @templateFunction()
		model = ls.expand @candidate().data?.sync.id
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
			link.style.display = 'none'
			document.body.appendChild link
			link.click()
			document.body.removeChild link
		else
			content = zip.generate()
			location.href = 'data:application/zip;base64,' + content

		return

	@delegate('click', '#lookup .btn-create-diagram') ->
		do @createDiagram

	@delegate('click', '#lookup .btn-remove-diagram') (item) ->
		if item is @candidate()
			@candidate null

		@removeDiagram item.title()

	@delegate('click', '#lookup .btn-edit-diagram') (item) ->
		@navigate "edit/#{item.title()}"

	@delegate('click', '#lookup .btn-close-diagram') (item) ->
		@closeDiagram item.title()

	@delegate('click', '#lookup .btn-rename-diagram') (item) ->
		item.isRenamed yes

	@delegate('click', '#lookup .btn-generate-code') (item) ->
		@candidate item
		@navigate 'generation'

	@delegate('click', '#lookup .btn-share-diagram') (item) ->
		@candidate item
		@navigate 'share'

	oldActived = null
	@delegate('click', '#lookup .diagram-item') (item) ->
		oldActived?.isActive no
		oldActived = item
		item.isActive yes

	@computed \
	shareLink : ->
		if @candidate()
			"#{location.origin}/#remote/#{@candidate().id()}"
		else
			''

	#### Authorization
	
	@computed \
	invalidPassword2 : ->
		@inputPassword() != @inputPassword2()

	calcSHA1 = (str) ->
		new jsSHA(str, 'TEXT').getHash('SHA-1', 'HEX')

	checkFields : ->
		if @invalidLogin() || @invalidPassword()
			return false

		unless /^\w{4,}$/.test @inputLogin()
			@invalidLogin yes
			return false

		if @inputPassword().length == 0
			@invalidPassword yes
			return false

		return true

	@delegate('submit', '#login form') (v, event) ->
		do event.preventDefault
		return unless @checkFields()

		xhr = new XMLHttpRequest
		xhr.open 'POST', '/login', yes
		xhr.onreadystatechange = =>
			return if xhr.readyState != 4

			if xhr.status == 401
				if xhr.statusText == 'Unknown user'
					@invalidLogin yes
				else if xhr.statusText == 'Invalid password'
					@invalidPassword yes
			else if xhr.status == 200
				do @authorize

		xhr.setRequestHeader 'Content-Type', 'application/json'
		xhr.send JSON.stringify {
			username : @inputLogin()
			password : calcSHA1 @inputPassword()
		}

	@delegate('submit', '#signup form') (v, event) ->
		do event.preventDefault
		return unless @checkFields()
		return if @invalidPassword2()

		xhr = new XMLHttpRequest
		xhr.open 'POST', '/signup', yes
		xhr.onreadystatechange = =>
			return if xhr.readyState != 4

			if xhr.status == 401
				if xhr.statusText == 'Existing user'
					@invalidLogin yes
			# else if xhr.status == 200
				# console.log 'signup!'
				# do @authorize

		xhr.setRequestHeader 'Content-Type', 'application/json'
		xhr.send JSON.stringify {
			username : @inputLogin()
			password : calcSHA1 @inputPassword()
		}

	@delegate('change', '#login-login, #signup-login') ->
		@invalidLogin no

	@delegate('change', '#login-password, #signup-password') ->
		@invalidPassword no

class DiagramItemViewModel extends BaseViewModel
	constructor : (@sync) ->
		@title = sync.observer 'title'
		@id    = sync.observer 'id'
		@lastModifiedInMs = sync.observer 'lastModified'

		@isRenamed = ko.observable no
		@isOpen    = ko.observable no
		@isActive  = ko.observable no

		super

	open : (cb) ->
		work = (key, doc) =>
			sync = new Synchronizer diagramSpec, key
			sync.onchange = (=>
				@lastModifiedInMs Date.now()
			).throttle(1000)

			sync.attach doc
			do sync.markAsMaster
			@data = new DiagramViewModel sync
			@isOpen yes
			do cb

		share.open "edit:#{@id()}", 'json', {
			authentication : authField
		}, (err, doc) =>
			return if err?

			if r = doc.get()
				(-> work ls.allocate(r), doc).defer()
			else
				data = { essentials : [], relationships : [] }
				doc.set data, -> work ls.allocate(data), doc

	close : ->
		do @data.sync.doc.close
		ls.remove @data.sync.id
		@data = null
		@isOpen no

	@computed \
	lastModified : ->
		d = new Date(@lastModifiedInMs() - new Date().getTimezoneOffset() * 1000)
		"#{d.toLocaleDateString()} #{d.toLocaleTimeString()}"

module.exports = CommonViewModel