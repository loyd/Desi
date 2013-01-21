ko = require 'ko'

ko.extenders.extMode = (self) ->
	ko.utils.extend self, extModeMethods
	return self

extModeMethods = do (obsFns = ko.observableArray.fn) ->
	methods =
		subscribeAll : (hash, self) ->
			for event, handler of hash
				@subscribe handler, self, event

			this

	makeMethod = (name, body) ->
		methods[name] = ->
			args = Array.from(arguments)
			@notifySubscribers args, "#{name}:before"
			res = body.apply(@, arguments)
			@notifySubscribers [args, res], "#{name}:after"
			res

	for name in Object.keys(obsFns)
		makeMethod name, obsFns[name]

	makeMethod 'move', ->
		arr = @peek()
		do @valueWillMutate
		res = arr.move arguments...
		do @valueHasMutated
		res

	methods