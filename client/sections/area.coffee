ko   = require 'ko'
Base = require 'libs/base_mvm'

class Area extends Base
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

module.exports = Area