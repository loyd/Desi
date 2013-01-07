ko = require 'ko'

class BaseModel

	constructor : ->
		for propName, propVal of this when ~propName.indexOf '#'
			[key, type] = key.split '#'
			switch type
				when 'observable'
					@[key] = ko.observable null
				when 'observableArray'
					@[key] = ko.observableArray null

	@observable = (names...) ->
		for name in args
			@::["#{name}#observable"] = true

	@observableArray = (names...) ->
		for name in names
			@::["#{name}#observableArray"] = true
