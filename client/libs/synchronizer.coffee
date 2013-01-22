ko = require 'ko'
ls = require 'libs/local_storage'

class Synchronizer
	createDataFromSpec = (spec) ->
		return switch spec.type
			when 'object'
				data = {}
				for prop of spec.data
					data[prop] = createDataFromSpec spec.data[prop]
				data
			when 'array' then []
			else spec.default

	constructor : (@spec, @id) ->
		unless id?
			data = createDataFromSpec spec
			@id = ls.allocate data

		@observers = {}

	leaveStorage : ->
		ls.remove @id
		@id = null
		for prop, obs of @observers
			obs.id = null
			if obs.type is 'array'
				do w.sync.leaveStorage for w in obs.peek()

		return

	observer : (prop, opts) ->
		if arguments.length == 1 && typeof prop is 'object'
			opts = prop
			prop = null

		if prop
			spec = @spec.data[prop]
			id   = ls.expand(@id, 0)[prop]
		else
			{spec, id} = this

		if spec.type is 'array' && !opts.adapter && !opts.classAdapter
			return null

		obs = if spec.type is 'array'
			adapter = if opts.classAdapter
				(itemId) -> new opts.classAdapter(
					new Synchronizer(spec.item, itemId)
				)
			else if opts.adapter
				(itemId) -> opts.adapter new Synchronizer(spec.item, itemId)

			makeArrayObserver(spec, ls.expand(id, 0), adapter)
		else
			makeObserver(spec, ls.expand id)

		obs.id   = id
		obs.type = spec.type
		@observers[prop] = obs

	concretize : (prop) ->
		new Synchronizer @spec.data[prop], ls.expand(@id, 0)[prop]

	makeObserver = (spec, init) ->
		if spec.validate
			val = init ? spec.default
			obs = ko.computed {
				read : -> val
				write : (v) ->
					if spec.validate(v)
						val = v
						ls obs.id, v if obs.id
			}
		else
			obs = ko.observable init ? spec.default
			obs.subscribe (v) -> ls id, v if obs.id
		obs

	makeArrayObserver = (spec, init, wrap) ->
		obs = ko.observableArray(init.map wrap).extends(extMode: on)

		table = {}
		for event of handlers then do (event) ->
			table[event] = if ~event.indexOf ':after'
				 ([args, res]) ->
					handlers[event] obs.peek(), obs.id, args, res if obs.id
			else
				(args) ->
					handlers[event] obs.peek(), obs.id, args if obs.id

		obs.observableAll table
		obs

handlers = {
	'push:before' : (arr, id, args) ->
		val = ls id
		addition = ''
		for arg in args
			addition += ',' + arg.sync.id

		if val[0]
			ls id, addition[1..]
		else
			ls id, val + addition

		return

	'pop:before' : (arr, id) ->
		val = ls id
		lastComma = val.lastIndexOf ','

		if ~lastComma
			ls id, val[...lastComma]
			do arr.last().sync.leaveStorage

		return

	'unshift:before' : (arr, id, args) ->
		val = ls id
		addition = ''
		for arg in args
			addition += arg.sync.id + ','

		if val[0]
			ls id, addition[...-1]
		else
			ls id, addition + val

		return

	'shift:before' : (arr, id) ->
		val = ls id
		firstComma = val.indexOf ','

		if ~firstComma
			ls id, val[firstComma+1..]
			do arr.first().sync.leaveStorage

		return

	'splice:before' : (arr, id, [start, count, elems...]) ->
		val = ls id
		start = arr.length + start if start < 0

		addition = ''
		if elems.length > 0
			for arg in args
				addition += arg.sync.id + ','

		startIndex = 0
		while start--
			startIndex = str.indexOf ',', startIndex + 1

		endIndex = startIndex
		while count--
			endIndex = str.indexOf ',', endIndex + 1

		if ~endIndex
			ls id, str[..startIndex] + addition +  + str[endIndex+1..]
		else
			ls id, str[..startIndex] + addition[...-1]

		for i in [start...start+count] by 1
			do arr[i].sync.leaveStorage

		return

	'reverse:after' : refreshFromWrap = (arr, id) ->
		val = (wrapper.sync.id for wrapper in arr).join ','
		ls id, "[#{val}]"
		return

	'sort:after' : refreshFromWrap
	'move:after' : refreshFromWrap

	'remove:after' : (arr, id, args, res) ->
		do wrapper.sync.leaveStorage for wrapper in res
		refreshFromWrap arr
		return

	'removeAll:after' : (arr, id, args, res) ->
		do wrapper.sync.leaveStorage for wrapper in res
		ls id, '[]'
		return
}

module.exports = Synchronizer