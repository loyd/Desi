ko     = require 'ko'
Router = require './router'

class Base

	initAdopted = (key) ->
		return (val) ->
			@[key] = val

	constructor : ->
		for propName, propVal of this when ~propName.indexOf '#'
			[key, postfix] = key.split '#'
			switch postfix
				when 'observable'
					@[key] = ko.observable null
				when 'observableArray'
					@[key] = ko.observableArray null
				when 'handler'
					val = this[propVal] if typeof propVal is 'string'
					router.listen key, val.bind this
				when 'computed'
					@[key] = ko.computed propVal, this
				when 'adopted'
					@[key] = initAdopted key

	createAccessorMaker = (postfix) ->
		return (names...) ->
			for name in names
				@::[name + '#' + postfix] = on
	
	@observable      = createAccessorMaker 'observable'
	@observableArray = createAccessorMaker 'observableArray'
	@adopted         = createAccessorMaker 'adopted'

	@computed = (hash) ->
		for key, val of hash
			@::["#{key}#computed"] = val

class BaseModel extends Base

class BaseViewModel extends Base
	router = new Router

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

module.exports = { Base, BaseModel, BaseViewModel }