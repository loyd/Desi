$ = localStorage

WRITE_TIMEOUT = 300 # [ms]
NEXT_ID_KEY   = '__nextId'

commandRemove = Object.create null
waiters = {}
ls = (key, value) ->
	if arguments.length == 1
		return waiters[key] ? $.getItem(key)
	
	if key of waiters
		waiters[key] = value
		return
	else
		waiters[key] = value
		setTimeout ->
			if waiters[key] is commandRemove
				$.removeItem key
			else
				$.setItem key, waiters[key]
			delete waiters[key]
		, WRITE_TIMEOUT
		return

id = ls NEXT_ID_KEY
nextId = (value) ->
	if arguments.length == 1
		ls(NEXT_ID_KEY, value)
		id = value
	else
		ls(NEXT_ID_KEY, +id + 1)
		return id++
nextId(id ? 0)

ls.allocate = (value) ->
	if typeof value is 'object'
		if Array.isArray value
			nValue = value.map ls.allocate
		else
			nValue = {}
			for prop of value
				nValue[prop] = ls.allocate value[prop]
	else
		nValue = value

	key = nextId()
	ls key, JSON.stringify(nValue)
	key

ls.expand = (key) ->
	root = JSON.parse(ls key)
	
	if typeof root is 'object'
		if Array.isArray root
			root = root.map ls.expand
		else
			for prop of root
				root[prop] = ls.expand root[prop]

	root

ls.remove = (key) ->
	root = JSON.parse(ls key)

	if typeof root is 'object'
		if Array.isArray root
			root.forEach ls.remove
		else
			for prop of root
				ls.remove root[prop]
	
	ls key, commandRemove
	return

ls.clear = ->
	do $.clear
	nextId 0
	return

module.exports = ls
