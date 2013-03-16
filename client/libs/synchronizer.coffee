ko = require 'ko'
ls = require 'libs/local_storage'

class Synchronizer
	ptrTable = {}

	@registerPid = (pid, what) ->
		ptrTable[pid] = what

	makePtr = ->
		profileTop = ls.expand ls('profile'), 0
		profileId  = ls profileTop['login']
		ptrId      = ls profileTop['freePtrId']
		ls profileTop['freePtrId'], Number(ptrId) + 1
		"#{profileId}:#{ptrId}"

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

	attach : (@doc) ->
		doc.on 'remoteop', (op) =>
			target = this
			if op.li || op.ld || op.lm
				index = op.p.pop()
				console.assert(index in [0, target.peek().length])

			for prop in op.p
				target = if target.type == 'object'
					target.children[prop] || target.observers[prop]
				else if target.type == 'array'
					target[prop]
				else
					debugger

			target.localMutation = yes

			if op.li
				if index == 0
					target.unshift target.adapter(ls.allocate op.li)
				else
					target.push target.adapter(ls.allocate op.li)
			else if op.ld
				if index == 0
					do target.shift
				else
					do target.pop
			else if op.lm
				target.move index, op.lm, 1
			else if op.od && op.oi
				target op.oi
			else
				debugger

			target.localMutation = no

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
		console.log 'path: ', path.join(':')
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

		obs.id     = id
		obs.type   = spec.type
		obs.title  = prop || @title
		obs.parent = this
		obs.sync   = obs
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
			old = v

			if obs.id?
				wv = "\"#{v}\"" if spec.type in ['string', 'pointer']
				ls obs.id, wv

			[master, path] = route obs
			return unless master
			do master.touch
			master.submit {
				p  : path
				od : old
				oi : v
			}

			return

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
			return if @localMutation

			lastIndex = @peek().length - 1
			return unless master
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
			lastIndex = arr.length - 1

			if ~lastComma
				ls @id, "[#{val[...lastComma]}]"
				do arr[lastIndex].sync.leaveStorage
			else
				ls @id, "[]"

			[master, path] = route this
			do master.touch
			return if @localMutation

			return unless master
			path.push lastIndex
			master.submit {
				p  : path
				ld : res.sync.snapshot()
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
			return if @localMutation

			return unless master
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

			do @peek()[0].sync.leaveStorage
			[master, path] = route this
			do master.touch
			return if @localMutation

			return unless master
			path.push 0
			master.submit {
				p  : path
				ld : res.sync.snapshot()
			}

		splice : ([start, count, elems...]) ->
			# Sync with sharejs not implemented
			debugger

			val = unwrap @id
			arr = @peek()
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
				ls @id, "[#{str[..startIndex] + addition +  + str[endIndex+1..]}]"
			else
				ls @id, "[#{str[..startIndex] + addition[...-1]}]"

			for i in [start...start+count] by 1
				do arr[i].sync.leaveStorage

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

		delete : ([elem], index) ->
			val = unwrap @id
			if index == 0
				ls @id, "[#{val[val.indexOf(',')+1..]}]"
			else if index == @peek().length - 1
				ls @id, "[#{val[...val.lastIndexOf(',')]}]"
			else
				newVal = val.replace ",#{@id},", ''
				ls @id, "[#{newVal}]"
			
			do elem.sync.leaveStorage
			[master, path] = route this
			do master.touch
			return if @localMutation

			return unless master
			path.push index
			master.submit {
				p  : path
				ld : elem.sync.snapshot()
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