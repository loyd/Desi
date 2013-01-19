ko = require 'ko'

ko.extenders.extEvents = (self) ->
	ko.utils.extend self, extEventsMethods
	return self

extEventsMethods = do (obsFns = ko.observableArray.fn) ->
	methods = {}

	Object.keys(obsFns).forEach (name) ->
		methods[name] = ->
			obsFns[name].apply(@, arguments)
			@notifySubscribers Array.from(arguments), name
			this

	methods.subscribeAll = (hash, self) ->
		for key, val of hash
			@subscribe val, self, key

		this

	methods