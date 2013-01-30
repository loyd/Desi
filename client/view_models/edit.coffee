ko                    = require 'ko'
BaseViewModel         = require 'libs/base_view_model'
ClassDiagramViewModel = require './class_diagram'

class EditViewModel extends BaseViewModel
	sectionTmpl : 'edit-tmpl'

	constructor : (@sync) ->
		@openDiagrams  = {}
		@activeDiagram = ko.observable null
		super

	@route {
		'edit' : -> @navigate 'lookup'

		'edit/:title' : (title) ->
			sync = @sync.concretize()
			@openDiagrams[title] = new ClassDiagramViewModel sync

		'edit/:title/close' : (title) ->
	}

module.exports = EditViewModel