ko        = require 'ko'
router    = new (require './router')
delegator = new (require './delegator')

class Base

	emptyArray = []

	constructor : ->
		for propName, propVal of this when ~propName.indexOf '#'
			[key, postfix] = key.split '#'

			switch postfix
				when 'observable'
					@[key] = ko.observable null
				when 'observableArray'
					@[key] = ko.observableArray(emptyArray)
						.extend(extEvents: on)
				when 'computed'
					@[key] = ko.computed propVal, this
				when 'adopted'
					@[key] = @model[key]
				when 'adoptedArray'
					@[key] = null
				when 'hashHandler'
					val = this[propVal] if typeof propVal is 'string'
					router.listen key, val.bind this

	@observable = (names...) ->
		for name in names
			@::["#{name}#observable"] = on

	@observableArray = (hash) ->
		for name in names
			@::["#{name}#observableArray"] = on

	@computed = (hash) ->
		for key, val of hash
			@::["#{key}#computed"] = val

class BaseModel extends Base

class BaseViewModel extends Base
	constructor : (@model) ->
		super

	@adopted = (names...) ->
		for name in names
			@::["#{name}#adopted"] = on

	@adoptedArray = (names...) ->
		for name in names
			@::["#{name}#adoptedArray"] = on


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
				hashOrFn = "__anon#{anonNum++}" : hashOrFn

			for key, val of hashOrFn
				@::[key] = val

				delegator.delegate event, sel, @, key

module.exports = { Base, BaseModel, BaseViewModel }