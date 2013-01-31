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

		return

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

		return

	anonNum = 0
	@delegate = (event, sel = '') ->
		sel = "#{[@::viewRoot]} #{sel}".trim()
		return (hashOrFn) =>
			if typeof hashOrFn is 'function'
				hash = {}
				hash["__anon#{anonNum++}"] = hashOrFn
				hashOrFn = hash

			for key, val of hashOrFn
				@::[key] = val

				delegator.delegate event, sel, @, key

			return

module.exports = BaseViewModel