BaseViewModel         = require 'libs/base_view_model'
Synchronizer          = require 'libs/synchronizer'
ko                    = require 'ko'

class LookupViewModel extends BaseViewModel
	sectionTmpl : 'lookup-tmpl'
	viewRoot    : '#lookup'

	constructor : (@sync) ->
		@diagrams = sync.observer
			classAdapter : DiagramItemViewModel

		super

	newDiagram : ->
		sync = new Synchronizer @spec.item
		diag = new DiagramItemViewModel sync
		date = new Date
		diag.lastModifiedInMs +date + date.getTimezoneOffset() * 1000
		@diagrams.push diag

	@delegate('click', '.btn-remove-diagram') \
	rmDiagram : (diagram) ->
		@diagrams.remove diagram

class DiagramItemViewModel extends BaseViewModel
	viewRoot : '.diagram-item'

	constructor : (@sync) ->
		@title            = sync.observer 'title'
		@lastModifiedInMs = sync.observer 'lastModified'

		@renaming = ko.observable no
		@isOpen   = ko.observable no
		@isActive = ko.observable no

		super

	@delegate('click', '.btn-edit-diagram') \
	open : ->
		@isOpen yes
		@navigate "edit/#{@title}"

	@delegate('click', '.btn-close-diagram') \
	close : ->
		@isOpen no

	oldActived = null
	@delegate('click') ->
		oldActived?.isActive no
		oldActived = this
		@isActive yes

	@delegate('click', '.btn-rename-diagram') ->
		@renaming yes

	@computed \
	lastModified : ->
		d = new Date(@lastModifiedInMs() - new Date().getTimezoneOffset() * 1000)
		"#{d.toLocaleDateString()} #{d.toLocaleTimeString()}"

module.exports = LookupViewModel