ko              = require 'ko'
{BaseViewModel} = require 'libs/base_class'

class AreaViewModel extends BaseViewModel
	sectionTmpl : 'area-tmpl'

	constructor : ->
		super
		@diagrams      = ko.observableArray null
		@activeDiagram = ko.observable null

	toDiagram : (project, name) ->

	@route {
		'area' : -> @navigate 'lookup'

		'area/:project' : (project) ->
			@navigate 'lookup/#{project}'

		'area/:project/:name' : 'toDiagram'
	}

module.exports = AreaViewModel