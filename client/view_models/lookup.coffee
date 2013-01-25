BaseViewModel = require 'libs/base_view_model'

class LookupViewModel extends BaseViewModel
	sectionTmpl : 'lookup-tmpl'

	constructor : (@sync) ->
		super

		@diagrams = sync.observer
			classAdapter : DiagramElemViewModel

class DiagramElemViewModel extends BaseViewModel
	constructor : (@sync) ->
		super

		@title            = sync.observer 'title'
		@lastModifiedInMs = sync.observer 'lastModified'

	@computed \
	lastModified : ->
		new Date(@lastModifiedInMs() - new Date().getTimezoneOffset() * 1000)
			.toLocaleDateString()

module.exports = LookupViewModel