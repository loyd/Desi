Router = require './router'
ko     = require 'ko'

class BaseViewModel
	router = new Router

	adopted = (key) ->
		return (val) ->
			@[key] = val

	constructor : ->
		for propName, propVal of this when ~propName.indexOf '#'
			[key, type] = key.split '#'
			switch type
				when 'handler'
					val = this[val] if typeof val is 'string'
					router.listen key, val.bind this
				when 'computed'
					@[key] = ko.computed propVal, this
				when 'adopted'
					@[key] = adopted key

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

	@adopted = (names...) ->
		for name in args
			@::["#{name}#adopted"] = true

module.exports = BaseViewModel