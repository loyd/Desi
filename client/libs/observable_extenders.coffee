ko = require 'ko'

ko.extenders.extEvents = (self) ->
	ko.utils.extend self, extEventsMethods
	return self

extEventsMethods = do (obsFns = ko.observableArray.fn) ->
	methods = {}

	Object.keys(obsFns).forEach (name) ->
		methods[name] = ->
			args = Array.from(arguments)
			@notifySubscribers args, "#{name}:before"
			obsFns[name].apply(@, arguments)
			@notifySubscribers args, "#{name}:after"
			this

	methods.subscribeAll = (hash, self) ->
		for event, handler of hash
			@subscribe handler, self, event

		this

	methods