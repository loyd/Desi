Router = require './router'

class BaseViewModel
	router = new Router

	constructor : ->
		for tmplStr, cb of @constructor.routingTable
			cb = this[cb] if typeof cb is 'string'
			router.listen tmplStr, cb.bind this

	navigate : router.navigate
	@route = (tmpl, cb) ->
		@routingTable ?= {}
		if typeof tmpl is 'object'
			@route tpl, cb for tpl, cb of tmpl
		else for tmpl in tmpl.split ','
			@routingTable[tmpl.trim()] = cb

module.exports = BaseViewModel