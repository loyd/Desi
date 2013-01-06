Router = require './router'
ko     = require 'ko'

class BaseMVM
	router = new Router

	constructor : ->
		for propName, propVal of this when ~propName.indexOf '#'
			[key, type] = key.split '#'
			switch type
				when 'handler'
					val = this[val] if typeof val is 'string'
					router.listen key, val.bind this
				when 'computed'
					@[key] = ko.computed propVal, this
				when 'observable'
					@[key] = ko.observable null
				when 'observableArray'
					@[key] = ko.observableArray null

	navigate : router.navigate
	@route = (tmpl, cb) ->
		if typeof tmpl is 'object'
			@route tpl, cb for tpl, cb of tmpl
		else for tmpl in tmpl.split ','
			key = "#{tmpl.trim()}#handler"
			if @::[key]?
				@::[key].push cb
			else
				@::[key] = [cb]

	@computed = (hash) ->
		for key, val of hash
			@::["#{key}#computed"] = val

	@observable = (names...) ->
		for name in args
			@::["#{name}#observable"] = true

	@observableArray = (names...) ->
		for name in names
			@::["#{name}#observableArray"] = true

module.exports = BaseMVM