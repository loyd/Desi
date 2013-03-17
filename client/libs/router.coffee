{RBTree} = require 'bintrees'

class Router
	instance = null
	constructor : ->
		return instance if instance
		instance = this

		@currentHash = null
		@tmplsTree   = new RBTree Tmpl.compare
		@tmplsCache  = {}

		addEventListener 'hashchange', @onchange

	refresh : =>
		@currentHash = null
		do @onchange

	onchange : =>
		newHashValue = location.hash[1..]
		return if @currentHash == newHashValue && !@hashIsChanged

		@hashIsChanged = no
		iter = @tmplsTree.iterator()
		while (tmpl = iter.next()) != null
			tmpl.apply @currentHash, newHashValue
			return if @hashIsChanged

		@currentHash = newHashValue

	listen : (tmplStr, cbIn, cbOut) =>
		if tmplStr not of @tmplsCache
			tmpl = new Tmpl tmplStr
			@tmplsTree.insert tmpl
			@tmplsCache[tmplStr] = tmpl

		tmpl ?= @tmplsCache[tmplStr]

		tmpl.addCallbackIn cbIn if cbIn
		tmpl.addCallbackOut cbOut if cbOut

	forget : (tmplStr, cbIn, cbOut) =>
		tmpl = @tmplsCache[tmplsStr]
		if arguments.length == 1
			@tmpl.remove tmpl
			delete @tmplsCache[tmplsStr]
		else if tmpl?
			tmpl.rmCallbackIn cbIn if cbIn
			tmpl.rmCallbackOut cbOut if cbOut

	navigate : (urlHash) =>
		@hashIsChanged = yes
		(=> location.hash = '#' + urlHash).defer()

class Tmpl
	@compare = (one, two) ->
		return 0 if one == two

		if one.priority == two.priority
			if one.str == two.str then 0
			else +(one.str > two.str) || -1
		else +(one.priority > two.priority) || -1

	constructor : (@str) ->
		@stackIn  = []
		@stackOut = []

		do @countPriority
		do @makeRegExp

	###
		share/someuser/test

		*   -> a
		:id -> b      c > b > a
		id  -> c

		String of template     | Parts | Priority
		-----------------------+-------+---------
		*                      |   1   | a
		:section/*             |   2   | ba
		:section/:id/*         |   3   | bba
		:section/:id/:act      |   3   | bbb
		:section/someuser/*    |   3   | bca
		:section/someuser/:act |   3   | bcb
		:section/someuser/test |   3   | bcc
		share/*                |   2   | ca
		share/:id/*            |   3   | cba
		share/:id/:act         |   3   | cbb
		share/someuser/*       |   3   | cca
		share/someuser/test    |   3   | ccc
	###
	countPriority : ->
		@priority = @str.split('/').map (p) ->
			if p is '*' then 'a' else if p[0] is ':' then 'b' else 'c'
		.join('')

	makeRegExp : ->
		regParts = for part, i in @str.split('/')
			if part[0] is ':'
				'(.+?)'
			else if part is '*'
				'.+?'
			else
				"#{part}"

		@regExp = new RegExp "^#{regParts.join('/')}$"

	addCallbackIn : (cbIn) ->
		@stackIn.push cbIn

	addCallbackOut : (cbOut) ->
		@stackOut.push cbOut

	rmCallbackIn : (cb) ->
		if ~(index = @stackIn.indexOf cb)
			@stackIn.splice index, 1

	rmCallbackOut : (cb) ->
		if ~(index = @stackOut.indexOf cb)
			@stackOut.splice index, 1

	apply : (strOut, strIn) ->
		if resOut = strOut?.match @regExp
			do resOut.shift
			cbOut resOut... for cbOut in @stackOut

		if resIn = strIn?.match @regExp
			do resIn.shift
			cbIn resIn... for cbIn in @stackIn

		return

	toString : -> @str

module.exports = Router