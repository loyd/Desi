ko            = require 'ko'
BaseViewModel = require 'libs/base_view_model'

class AreaViewModel extends BaseViewModel
	sectionTmpl : 'area-tmpl'

	constructor : ->
		@diagrams      = ko.observableArray null
		@activeDiagram = ko.observable null
		super

	toDiagram : (project, name) ->

	@route {
		'area' : -> @navigate 'lookup'

		'area/:project' : (project) ->
			@navigate 'lookup/#{project}'

		'area/:project/:name' : 'toDiagram'
	}

module.exports = AreaViewModel