"use strict"

makeAccs = (obj) -> (v) ->
	if arguments.length
		obj.set v
	else
		obj.get()

#### Numbers

'abs ceil floor cos sin tan acos asin atan sqrt'.split(' ')
.forEach (name) ->
	Number::[name] = ->
		Math[name](@)

Number::sqr = ->
	this * this

Number::sign = ->
	this && @abs() / this || 0

Number::signStr = ->
	@sign() == -1 && '-' || '+'

Number::pow = (power) ->
	Math.pow(@, power)

Number::degree = ->
	@ * Math.PI / 180

Number::toSecond = ->
	@ / 1000

Number::round = (pr = 0) ->
	pr = Math.pow(10, pr).toFixed(if pr < 0 then -pr else 0)
	Math.round(@ * pr) / pr

Number::times = (fn) ->
	fn(i) for i in [0...@] by 1
	return

#### Strings

String::low = String::toLowerCase
String::up  = String::toUpperCase

String::letters = ->
	@split ''

isSpace = /\s+/
String::words = ->
	@split isSpace

#### Arrays

Array.from = (arrayLike) ->
	return [] unless arrayLike.length?
	
	args = new Array arrayLike.length
	for i in [0...args.length] by 1
		args[i] = arrayLike[i]

	args

# Get/Set first element in array
Array::first = makeAccs
	set : (v) -> @[0] = v
	get : (v) -> @[0]

# Get/Set second element in array
Array::first = makeAccs
	set : (v) -> @[1] = v
	get : (v) -> @[1]

# Get/Set penult element (if it exists) in array
Array::penult = makeAccs
	get :     -> @[@length-2]     if @length >= 2
	set : (v) -> @[@length-2] = v if @length >= 2

# Get/Set last element (if it exists) in array
Array::last = makeAccs
	get :     -> @[@length-1]     if @length >= 1
	set : (v) -> @[@length-1] = v if @length >= 1

Array::insert = (index, elems...) ->
	@splice index, 0, elems...
	return

Array::append = (targets...) ->
	@push target... for target in targets
	return

Array::swap = (i, j, len = 1) ->
	if len == 1
		[this[i], this[j]] = [this[j], this[i]]
	else
		@swap(i + shift, j + shift) for shift in [0...len] by 1

	return

Array::move = (from, to, len = 1) ->
	return if from == to

	if len == 1 && (from - to).abs() == 1
		return @swap from, to

	what = @splice from, len
	@insert to, what...
	return

Array::empty = ->
	@length == 0

Array::max = ->
	Math.max @...

Array::min = ->
	Math.min @...

Array::sum = ->
	@reduce (a, b) -> a + b

Array::average = ->
	@sum / @length

# Clears array from false elements
Array::clear = ->
	i = 0
	while i < @length
		unless @[i]
			@splice i, 1
		else ++i

	return

Array::partition = (fn) ->
	one = []; two = []
	(if fn(el,i,@) then one else two).push(el) for el, i in @
	[one, two]

Array::pairs = ->
	@partition (e, i) -> i % 2 is 0

Array::scan = (fn) ->
	for el, i in @ when (res = fn(el, i, @))
		return el
	false

Array::each = Array::forEach

#### Functions

Function::defer = (time = 0) ->
	setTimeout this, time