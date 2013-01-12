ko = require 'ko'

class Delegator
	constructor : (@root=document) ->
		@listeners = {}

	delegate : (event, sel, klass, key) ->
		unless event of @listeners
			@listenEvent event

		@listeners[event].push { sel, klass, key }

	checkSelector : (sel, what) ->
		nodes = @root.querySelectorAll sel
		return no unless nodes
		for node in nodes when elem is what
			return yes
		return no

	context : (node, klass) ->
		context  = ko.contextFor node
		instance = context.$data
		unless instance instanceof klass
			for parent in context.$parents when parent instanceof klass
				instance = parent
				break

		[instance, context.$data]

	listenEvent : (name) ->
		@listeners[name] = list = []
		@root.addEventListener name, (event) =>
			for elem in list when @checkSelector elem.sel, event.target
				[inst, data] = @context event.target, elem.klass
				inst[elem.key]?(data, event)
			return
		, off

module.exports = Delegator
