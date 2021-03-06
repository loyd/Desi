ko        = require 'ko'
router    = new (require './router')
delegator = new (require './delegator')

class BaseViewModel

	bindMethod : (fnOrName) ->
		if typeof fnOrName == 'string'
			this[fnOrName].bind this
		else
			fnOrName.bind this

	oDefEval = { deferEvaluation : on }

	constructor : (@sync) ->
		@spec = sync?.spec

		for propName, propVal of this when ~propName.indexOf '#'
			[key, postfix] = propName.split '#'

			switch postfix
				when 'computed'
					@[key] = ko.computed propVal, this, oDefEval
				when 'hashHandler'
					for val in propVal
						if typeof val is 'object'
							router.listen key,
								@bindMethod(val.in), @bindMethod(val.out)
						else
							router.listen key, @bindMethod(val)

	ref : -> @sync.pid

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
		if v = @::viewRoot?.trim()
			sel = sel.split(',').map((part) -> "#{v} #{part}".trim()).join(', ')

		sel = sel.trim()
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