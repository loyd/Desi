BaseViewModel = require 'libs/base_view_model'
Synchronizer  = require 'libs/synchronizer'
ko            = require 'ko'

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

	@delegate('click', '.btn-rm-diagram') \
	rmDiagram : (diagram) ->
		@diagrams.remove diagram

class DiagramItemViewModel extends BaseViewModel
	viewRoot : '.diagram-item'

	constructor : (@sync) ->
		@title            = sync.observer 'title'
		@lastModifiedInMs = sync.observer 'lastModified'

		@editing = ko.observable no

		super

	@delegate('click', '.title') \
	editTitle : ->
		@editing yes

	@computed \
	lastModified : ->
		d = new Date(@lastModifiedInMs() - new Date().getTimezoneOffset() * 1000)
		"#{d.toLocaleDateString()} #{d.toLocaleTimeString()}"

module.exports = LookupViewModel