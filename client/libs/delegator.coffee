ko = require 'ko'

class Delegator
	constructor : (@root=document) ->
		@listeners = {}

	delegate : (event, sel, klass, key) ->
		unless event of @listeners
			@listenEvent event

		@listeners[event].push { sel, klass, key }

	findElement : (selector, startNode) ->
		nodes = @root.querySelectorAll selector
		return null unless nodes
		
		for node in nodes
			return node if node is startNode

			parent = startNode
			while parent = parent.parentNode when parent is node
				return node

		return null

	expandContext : (node, klass) ->
		context  = ko.contextFor(node) || ko.contextFor(node.parentNode)
		instance = context.$data
		unless instance instanceof klass
			for parent in context.$parents when parent instanceof klass
				instance = parent
				break

		instance

	listenEvent : (name) ->
		@listeners[name] = list = []
		@root.addEventListener name, (event) =>
			for item in list when elem = @findElement item.sel, event.target
				inst = @expandContext event.target, item.klass
				inst[item.key]?(ko.dataFor(elem), event)
			return
		, off

module.exports = Delegator
