ko = require 'ko'

ko.extenders.extMode = (self) ->
	ko.utils.extend self, extModeMethods
	return self

extModeMethods = do (obsFns = ko.observableArray.fn) ->
	methods = {}
	aProto = Array.prototype
	Object.keys(obsFns).concat(['move', 'delete']).forEach (name) ->
		methods[name] = ->
			do @valueWillMutate
			res = if name of aProto
				aProto[name].apply(@peek(), arguments)
			else
				obsFns[name].apply(@, arguments)
			do @valueHasMutated
			@notifySubscribers [arguments, res], name
			res

	methods