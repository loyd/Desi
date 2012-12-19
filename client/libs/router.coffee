{RBTree} = require 'bintrees'

class Router
	constructor : ->
		@currentHash = null
		@tmplsTree   = new RBTree Tmpl.compare
		@tmplsCache  = {}

		addEventListener 'hashchange', @onchange

	onchange : =>
		newHashValue = location.hash[1..]
		return if @currentHash == newHashValue
		@currentHash = newHashValue

		@tmplsTree.each (tmpl) -> tmpl.apply newHashValue

	listen : (tmplStr, cb) =>
		if tmplStr not of @tmplsCache
			tmpl = new Tmpl tmplStr
			@tmplsTree.insert tmpl
			@tmplsCache[tmplStr] = tmpl

		(tmpl || @tmplsCache[tmplStr]).addCallback cb

	forget : (tmplStr, cb) =>
		if arguments.length == 1
			@tmpl.remove @tmplsCache[tmplsStr]
			delete @tmplsCache[tmplsStr]
		else
			@tmplsCache[tmplStr]?.rmCallback cb

	navigate : (urlHash) =>
		location.hash = '#' + urlHash

class Tmpl
	@compare = (one, two) ->
		return 0 if one == two

		if one.priority == two.priority
			if one.str == two.str then 0
			else +(one.str > two.str) || -1
		else +(one.priority > two.priority) || -1

	constructor : (@str) ->
		@stack = []

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

	addCallback : (fn) ->
		@stack.push fn

	rmCallback : (fn) ->
		if ~(index = @stack.indexOf fn)
			@stack.splice index, 1

	apply : (str) ->
		res = str.match @regExp
		return unless res

		do res.shift
		cb res... for cb in @stack

		return

	toString : -> @str

module.exports = Router