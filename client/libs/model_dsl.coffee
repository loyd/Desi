standardize = (opts) ->
	validate : switch yes
		when 'in' of opts
			if Array.isArray opts.in
				(v) -> v in opts.in
			else (v) ->
				for key, val of opts.in when val == v
					return true
				return false
		when 'of'    of opts then (v) -> v of opts.of
		when 'valid' of opts then opts.valid
	default : opts.def

waitingTarget = []
revisionWaiters = ->
	waitingTarget = waitingTarget.filter (targetAccs) ->
		if target = targetAccs()
			target.isTarget = no

		!target

module.exports = {
	object : (hash) ->
		do revisionWaiters

		for prop, value of hash
			hash[prop] = value?({}) || value

		type : 'object'
		data : hash
		isTarget : no

	array : (opts) ->
		type : 'array'
		item : opts.of?() || opts.of

	number : (opts) ->
		result = standardize opts
		result.type = 'number'
		result

	boolean : (opts) ->
		result = standardize opts
		result.type = 'boolean'
		result

	string : (opts) ->
		result = standardize opts
		if 'test' of opts
			result.validate = (v) -> v.test opts.test
		result.type = 'string'
		result

	pointer : (to) ->
		if target = to()
			target.isTarget = yes
		else
			waitingTarget.push to

		type    : 'pointer'
		default : 0

	extend : (parent = null, hash) ->
		result = type : 'object'
		result.data = Object.create parent?() || parent.data

		for own prop, value of hash
			result.data[prop] = value?({}) || value

		result
}