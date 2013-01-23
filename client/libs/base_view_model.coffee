ko        = require 'ko'
router    = new (require './router')
delegator = new (require './delegator')

class BaseViewModel

	constructor : (@sync) ->
		@spec = sync?.spec

		for propName, propVal of this when ~propName.indexOf '#'
			[key, postfix] = propName.split '#'

			switch postfix
				when 'computed'
					@[key] = ko.computed propVal, this
				when 'hashHandler'
					for val in propVal
						val = this[val] if typeof val is 'string'
						router.listen key, val.bind this

	@computed = (hash) ->
		for key, val of hash
			@::["#{key}#computed"] = val

	navigate : router.navigate
	@route = (tmpl, cb) ->
		if typeof tmpl is 'object'
			@route tpl, cb for tpl, cb of tmpl
		else for tmpl in tmpl.split ','
			key = "#{tmpl.trim()}#hashHandler"
			if @::[key]?
				@::[key].push cb
			else
				@::[key] = [cb]

	@viewRoot = (sel) ->
		@viewRoot_ = sel.trim()

	anonNum = 0
	@delegate = (event, sel) ->
		sel = "#{@viewRoot_} #{sel}"
		return (hashOrFn) =>
			if typeof hashOrFn is 'function'
				hashOrFn = {}
				hashOrFn["__anon#{anonNum++}"] = hashOrFn

			for key, val of hashOrFn
				@::[key] = val

				delegator.delegate event, sel, @, key

module.exports = BaseViewModel