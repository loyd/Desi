ko = require 'ko'
ls = require 'libs/local_storage'

class Synchronizer
	ptrTable = {}

	@registerPid = (pid, what) ->
		ptrTable[pid] = what

	pidGetter = null
	@registerPidGetter = (getter) ->
		pidGetter = getter

	makePtr = -> pidGetter()

	createDataFromSpec = (spec) ->
		return switch spec.type
			when 'object'
				data = {}
				for prop of spec.data
					data[prop] = createDataFromSpec spec.data[prop]
				data
			when 'array' then []
			else spec.default

	type : 'object'
	constructor : (@spec, @id, isFake) ->
		if id?
			if spec.isTarget
				@pid = ls.expand ls.expand(@id, 0)['__id']
		else
			data = createDataFromSpec spec
			if spec.isTarget
				@pid = data.__id = makePtr()
			@id = ls.allocate data unless isFake

		@observers = {}
		@children  = {}

	markAsMaster : ->
		@isMaster = yes

	applyOp : (op) ->
		target = this
		if op.li? || op.ld? || op.lm?
			index = op.p.pop()

		for prop in op.p
			target = if target.type == 'object'
				target.observers[prop] ? target.children[prop].sync
			else if target.type == 'array'
				target.peek()[prop].sync
			else
				debugger

		target.localMutation = yes

		if op.li?
			item = target.adapter(ls.allocate op.li)
			if index == 0
				target.unshift item
			else if index == target.peek().length
				target.push item
			else
				target.splice index, 0, item
		else if op.ld?
			if index == 0
				do target.shift
			else if index == target.peek().length
				do target.pop
			else
				target.splice index, 1
		else if op.lm?
			target.move index, op.lm, 1
		else if op.od? && op.oi?
			target op.oi
		else
			debugger

		target.localMutation = no

	attach : (@doc) ->
		doc.on 'remoteop', (ops) =>
			@applyOp op for op in ops

	submit : (action) ->
		@doc?.submitOp action

	snapshot : ->
		console.assert @id
		ls.expand @id

	touch : ->
		@onchange?()

	route = (start) ->
		path = []

		current = start
		while parent = current.parent
			if parent.type == 'array'
				console.assert(current.id)
				index = parent.routing[current.id]
				arr   = parent.peek()

				unless index? && arr[index].sync is current
					for elem, i in arr when elem.sync is current
						parent.routing[current.id] = index = i
						break

				path.push index
			else
				path.push current.title
 
			current = parent

		unless current.isMaster
			current = null

		do path.reverse
		# console.log 'path: ', path.join(':'), String([if current then 'fire'])
		return [current, path]

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

		if prop of @observers
			return @observers[prop]

		if prop
			spec = @spec.data[prop]
			id   = ls.expand(@id, 0)?[prop]
		else
			{spec, id} = this

		if spec.type is 'array' && !opts
			opts = adapter : (sync) -> sync.observer()

		obs = if spec.type is 'array'
			adapter = if opts.classAdapter
				(itemId) ->
					sync = new Synchronizer(spec.item, itemId)
					sync.parent = obs
					new opts.classAdapter sync
			else if opts.adapter
				(itemId) ->
					sync = new Synchronizer(spec.item, itemId)
					sync.parent = obs
					opts.adapter sync

			makeArrayObserver(spec, ls.expand(id, 0) || [], adapter)
		else
			makePrimeObserver(spec, ls.expand id)

		obs.id       = id
		obs.type     = spec.type
		obs.title    = prop || @title
		obs.parent   = this
		obs.sync     = obs
		obs.snapshot = @snapshot
		@observers[prop] = obs

	concretize : (prop) ->
		sync = new Synchronizer @spec.data[prop], ls.expand(@id, 0)[prop]
		sync.parent = this
		sync.title  = prop
		this.children[prop] = sync
		sync

	makePrimeObserver = (spec, init = spec.default) ->
		obs = ko.observable init
		old = init
		obs.subscribe (v) ->
			return old = v unless obs.id?

			wv = if spec.type in ['string', 'pointer'] then "\"#{v}\"" else v
			ls obs.id, wv

			return old = v if obs.localMutation

			[master, path] = route obs
			return unless master
			do master.touch
			master.submit {
				p  : path
				od : old
				oi : v
			}

			old = v

		if spec.type == 'pointer'
			obs.deref = -> ptrTable[obs()]
			obs.leaveStorage = ->
				ls.remove obs.id
				obs.id = null

		obs

	makeArrayObserver = (spec, init, wrap) ->
		obs = ko.observableArray(init.map wrap).extend(extMode: on)
		item.sync.parent = obs for item in obs()
		obs.routing = {}
		obs.adapter = wrap

		if spec.item.isTarget
			prevPids = []
			for item in obs()
				ptrTable[item.sync.pid] = item
				prevPids.push item.sync.pid

		for event, handler of handlers then do (handler) ->
			obs.subscribe ->
				handler.apply this, arguments[0]
			, obs, event

		if spec.item.isTarget
			obs.subscribe (arr) ->
				delete ptrTable[id] for id in prevPids
				prevPids = []
				for item in arr
					ptrTable[item.sync.pid] = item
					prevPids.push item.sync.pid

				return
		obs

	unwrap = (id) -> ls(id)[1...-1]
	handlers = {
		push : (args) ->
			val = unwrap @id
			addition = ''
			for arg in args
				addition += ',' + arg.sync.id
				arg.sync.parent = this

			ls @id, "[#{if val[0] then val + addition else addition[1..]}]"
			
			[master, path] = route this
			do master.touch
			return if @localMutation || !master

			lastIndex = @peek().length - 2
			for arg in args
				master.submit {
					p  : path.concat [++lastIndex]
					li : arg.sync.snapshot()
				}

			return

		pop : (args, res) ->
			val = unwrap @id
			arr = @peek()
			lastComma = val.lastIndexOf ','
			lastIndex = arr.length
			snapshot = res.sync.snapshot() unless @localMutation

			if ~lastComma
				ls @id, "[#{val[...lastComma]}]"
				do res.sync.leaveStorage
			else
				ls @id, "[]"

			[master, path] = route this
			do master.touch
			return if @localMutation || !master

			path.push lastIndex
			master.submit {
				p  : path
				ld : snapshot
			}

		unshift : (args) ->
			val = unwrap @id
			addition = ''

			for arg in args
				addition += arg.sync.id + ','
				arg.sync.parent = this

			ls @id, "[#{if val[0] then addition + val else addition[...-1]}]"

			[master, path] = route this
			do master.touch
			return if @localMutation || !master

			path.push 0
			for arg in args by -1
				master.submit {
					p  : path
					li : arg.sync.snapshot()
				}

			return

		shift : (args, res) ->
			val = unwrap @id
			firstComma = val.indexOf ','

			if ~firstComma
				ls @id, "[#{val[firstComma+1..]}]"
			else
				ls @id, "[]"

			snapshot = res.sync.snapshot() unless @localMutation

			do res.sync.leaveStorage
			[master, path] = route this
			do master.touch
			return if @localMutation || !master

			path.push 0
			master.submit {
				p  : path
				ld : snapshot
			}

		splice : ([start, count, elems...], deleted) ->
			if count == 1 && elems.length == 0
				return handlers.delete.call this, null, [start, deleted[0]]

			val = unwrap @id
			ids = elems.map (elem) -> elem.sync.id
			val = val.split(',').spliсe(start, count, ids...).join(',')
			ls @id, "[#{val}]"

			[master, path] = route this
			do master.touch
			sharing = @localMutation || !master

			if sharing
				path.push start
				for del in deleted
					master.submit {
						p  : path
						ld : del.sync.snapshot()
					}

			for del in deleted
				do del.sync.leaveStorage

			if sharing
				for elem in elems by -1
					master.submit {
						p  : path
						li : elem.sync.snapshot()
					}

			return

		reverse : refreshFromWrap = (args) ->
			# Sync with sharejs not implemented
			debugger
			val = (wrapper.sync.id for wrapper in @peek()).join ','
			ls @id, "[#{val}]"
			return

		sort : refreshFromWrap

		move : ([from, to, len]) ->
			if !len || len == 1
				val = JSON.parse(ls @id)
				val.move from, to, len
				ls @id, JSON.stringify val

				[master, path] = route this
				do master.touch
				return if @localMutation

				return unless master
				path.push from
				master.submit {
					p  : path
					lm : to
				}
			else
				refreshFromWrap.apply this, arguments

		delete : (args, [index, elem]) ->
			val = unwrap @id
			if index == 0
				ls @id, "[#{val[val.indexOf(',')+1..]}]"
			else if index == @peek().length - 1
				ls @id, "[#{val[...val.lastIndexOf(',')]}]"
			else
				newVal = val.replace ",#{@id},", ''
				ls @id, "[#{newVal}]"
			
			snapshot = elem.sync.snapshot() unless @localMutation
			do elem.sync.leaveStorage
			[master, path] = route this
			do master.touch
			return if @localMutation

			return unless master
			path.push index
			master.submit {
				p  : path
				ld : snapshot
			}

		remove : (args, res) ->
			# Sync with sharejs not implemented
			debugger
			do wrapper.sync.leaveStorage for wrapper in res
			refreshFromWrap @peek(), @id
			return

		removeAll : (args, res) ->
			# Sync with sharejs not implemented
			debugger
			do wrapper.sync.leaveStorage for wrapper in res
			ls @id, '[]'
			return
	}

module.exports = Synchronizer