standardize = (opts) ->
	validate : switch yes
		when 'in'    of opts then (v) -> v in opts.in
		when 'of'    of otps then (v) -> v of opts.of
		when 'valid' of opts then opts.valid
	default : opts.def

module.exports = {
	object : (hash) ->
		for prop, value of hash
			hash[prop] = value?({}) || value

		type : 'object'
		data : hash

	array : (opts) ->
		type : 'array'
		data : opts.of?() || opts.of

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

	extend : (parent = null, hash) ->
		result = type : 'object'
		result.data = Object.create parent?() || parent.data

		for own prop, value of hash
			result.data[prop] = value?({}) || value

		result
}