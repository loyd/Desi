ko        = require 'ko'
router    = new (require './router')
delegator = new (require './delegator')

class Base
	constructor : ->
		for propName, propVal of this when ~propName.indexOf '#'
			[key, postfix] = key.split '#'

			switch postfix
				when 'observable'
					@[key] = ko.observable null
				when 'observableArray'
					@[key] = ko.observableArray []
				when 'computed'
					@[key] = ko.computed propVal, this
				when 'adopted'
					@[key] = @model[key]
				when 'hashHandler'
					val = this[propVal] if typeof propVal is 'string'
					router.listen key, val.bind this

	@observable = (names...) ->
		for name in names
			@::["#{name}#observable"] = on

	@observableArray = (names...) ->
		for name in names
			@::["#{name}#observableArray"] = on

	@computed = (hash) ->
		for key, val of hash
			@::["#{key}#computed"] = val

class BaseModel extends Base

class BaseViewModel extends Base
	constructor : ->
		super

		if Model = @constructor.modelClass
			@model = new Model

	@adopted = (names...) ->
		for name in names
			@::["#{name}#adopted"] = on

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

	@model = (Class) ->
		@modelClass = Class

	@viewRoot = (sel) ->
		@viewRoot_ = sel.trim()

	@delegate = (event, sel) ->
		sel = "#{@viewRoot_} #{sel}"
		return (hash) =>
			for key, val of hash
				@::[key] = val

				delegator.delegate event, sel, @, key

module.exports = { Base, BaseModel, BaseViewModel }