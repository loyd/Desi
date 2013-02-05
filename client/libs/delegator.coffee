ko = require 'ko'

class Delegator
	constructor : (@root=document) ->
		@listeners = {}

	delegate : (event, sel, klass, key) ->
		unless event of @listeners
			@listenEvent event

		@listeners[event].push { sel, klass, key }

	checkSelector : (sel, elem) ->
		nodes = @root.querySelectorAll sel
		return no unless nodes
		
		for node in nodes
			return yes if node is elem

			parent = elem
			while parent = parent.parentNode when parent is node
				return yes

		return no

	expandContext : (node, klass) ->
		context  = ko.contextFor(node) || ko.contextFor(node.parentNode)
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
				[inst, data] = @expandContext event.target, elem.klass
				inst[elem.key]?(data, event)
			return
		, off

module.exports = Delegator
