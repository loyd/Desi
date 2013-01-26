"use strict"
console.warn('Good luck!') if process.platform isnt 'linux'

fs        = require 'fs'
path      = require 'path'
async     = require 'async'
jade      = require 'jade'
less      = require 'less'
coffee    = require 'coffee-script'
{exec}    = require 'child_process'
{inspect} = require 'util'

################################################################################
option '-o', '--output  [DIR]', 'directory for compiled code or docs'
option '-v', '--verbose [LVL]', 'level of message about errors (0..2)'

option '-n', '--name [NAME]', 'name of new view-model class/model'

task 'build:dev', 'build a development version', (options) ->
	do (o = options) ->
		o.verbose ?= 2
		o.output  ?= 'public'
		o.devMode  = on
		o.watching = no

	buildAll options

task 'watch:dev', 'build and watch development', (options) ->
	do setupJadeWatching
	do (o = options) ->
		o.verbose ?= 0
		o.output  ?= 'public'
		o.devMode  = on
		o.watching = yes

	buildAll options

task 'create:view-model', 'create view-model class', (options) ->
	{name}   = options
	basename = name.toPathName() + '.coffee'

	unless name.isValidName()
		handleExternError new Error 'Invalid name of class'

	fpath = "client/view_models/#{basename}"
	fs.exists fpath, (e) -> unless e then fs.writeFile fpath, """
		BaseViewModel = require 'libs/base_view_model'

		class #{name}ViewModel extends BaseViewModel
			constructor : (@sync) ->
				super
				
				#...

		module.exports = #{name}ViewModel
	""", handleExternError

task 'create:model', 'create model', (options) ->
	{name}   = options
	basename = name.toPathName() + '.coffee'

	unless name.isValidName()
		handleExternError new Error 'Invalid name'

	fpath = "client/models/#{basename}"
	fs.exists fpath, (e) -> unless e then fs.writeFile fpath, """
		{extend, number, string, array, object, boolean} = require 'libs/model_dsl'

		#{name} = object {
			# ...
		}

		module.exports = #{name}
	""", handleExternError

################################################################################
buildAll = (opts, done) ->
	async.waterfall [
		clear.bind null, opts.output
		async.parallel.bind async, [
			(ok) ->
				recurLook 'client', build.bind(null, opts, null), (err) ->
					ok(err) if err
					do ok unless opts.watching
				
				if opts.watching
					recurWatch 'client', build.bind(null, opts), ok
			(ok) ->
				fs.readdir 'components', (err, files) ->
					ok(err) if err
					async.forEach files, (fname, cmpl) ->
						prepare opts, null, "components/#{fname}", cmpl
					, (err) ->
						ok(err) if err
						do ok unless opts.watching

				if opts.watching
					recurWatch 'components', prepare.bind(null, opts), ok
		], done
	], (err) -> if err then handleExternError(err) else done?()

now = -> new Date().toTimeString()[0..7]
b   = (str) -> "\u001b[31m#{str}\u001b[0m"
handleBuildError = (err, path, verbose, next) ->
	next?() unless err
	makeErrorText path, +err.line, (text) ->
		console.log b "#{now()} - error at #{path}"
		console.log b text if text
		switch +verbose
			when 0 then console.log b err.message
			when 1 then console.log b inspect err, 15
			when 2 then throw err
			else throw new RangeError('Incorrectly --verbose')
		next?()

handleExternError = (err) -> throw err if err

String::count = (char) ->
	num = 0
	++num for c in this when c is char
	num

Number::format = (len) ->
	new Array(len - @toString().length + 1).join(' ') + this

errorVicinity = 2
makeErrorText = (path, errorLine, next) ->
	return do next unless errorLine
	startLine = errorLine - errorVicinity
	endLine   = errorLine + errorVicinity
	startLine = 0 if startLine < 0

	fs.readFile path, 'utf-8', (err, text) ->
		return next null if err
		maxLength = (text.count('\n') || 1).toString().length

		text = text.split('\n')[startLine-1..endLine-1].map (line, num) ->
			num += startLine
			ptr = if num is errorLine then '>' else ' '
			"  #{ptr} #{num.format maxLength}| #{line.replace /\t/g, '    '}"
		.join('\n')

		next text

build = (opts, event, fpath, done) ->
	return done?() if event is 'remove'

	rpath   = path.relative 'client', fpath
	[rpathWOext, ext] = rpath.match(/^(.+)(\..+)$/)[1..2]

	builder = builders[rpath] || builders[ext] || builders['*']
	proc = if builder is builders['*'] then 'cloned  ' else 'compiled'
	if typeof builder == 'function'
		builder = [ext, builder]

	opath = "#{opts.output}/#{rpathWOext + (builder[0] ? ext)}"

	async.waterfall [
		(next) -> mkdir path.dirname(opath), next
		(next) -> builder[1](fpath, opath, opts.devMode, next)
	], (err) ->
		if err
			handleBuildError(err, fpath, opts.verbose, done)
		else
			console.log "#{now()} - #{proc} #{fpath}"
			done?()

prepare = (opts, event, fpath, done) ->
	name = fpath.split('/')[1]
	return done?() unless name of preparers
	
	dpath = "components/#{name}"
	opath = "#{opts.output}/vendors/#{name}"

	async.waterfall [
		(next) -> mkdir opath, next
		(next) -> preparers[name](dpath, opath, opts.devMode, next)
	], (err) ->
		if err
			handleBuildError(err, dpath, opts.verbose, done)
		else
			console.log "#{now()} - prepared #{dpath}"
			done?()

################################################################################
compileCoffee = (filename, code) ->
	try code = coffee.compile code,
		{ filename, bare : yes }
	catch error
		error.message = error.message[error.message.indexOf(',')+2..]
			.replace /\son\sline\s(\d+)/, (str, line) ->
				error.line = line
				return ''

		return [error, null]

	return [null, code]

formatJadeError = (err) ->
	line = err.message.match(/^.*:(\d+)/)?[1]
	if line
		err.line = line
		err.message = err.message
			.split('\n')[1..].filter (line) ->
				!~line.search(/\d+\|/)
			.join('\n').trim()
	err

compileJade = (filename, code) ->
	try fn = jade.compile code,
		{ filename, pretty : yes }
	catch error
		return [formatJadeError error, null]

	return [null, (locals) ->
		try code = fn(locals)
		catch error
			throw formatJadeError error
		code
	]

setupJadeWatching = ->
	for dpath in ['client/styles', 'client/views']
		recurWatch dpath, (event, fpath, ok) ->
			return ok() if event is 'change'
			touch('client/index.jade', ok)
		, (err) -> handleExternError(err) if err

builders = {}

types = { svg : 'image/svg+xml', html : 'text/html' }
builders['index.jade'] = ['.html', (ipath, opath, dev, done) ->
	async.waterfall [
		(next) -> fs.readFile ipath, 'utf-8', next
		(code, next) ->
			[err, fn] = compileJade ipath, code
			next err if err

			locals =
				icon : 'favicon.png'
				templates : []
				styles : ['vendors/bootswatch/index.css']
				loader :
					main : 'requirejs_config'
					path : 'vendors/requirejs/index.js'

			async.parallel [
				recurLook.bind null, 'client/styles', (fpath, ok) ->
					return ok() if path.extname(fpath) isnt '.less'
					locals.styles.push \
						path.relative('client', fpath).replace /\.less$/, '.css'

					do ok

				recurLook.bind null, 'client/views', (fpath, ok) ->
					return ok() if path.extname(fpath) isnt '.jade'
					tmplPath = fpath.match(/^client\/(.*)\.jade$/)[1]
					type = path.extname(tmplPath)[1..]
					unless type of types
						msg = "Incorrect or unsupported type of #{fpath}"
						return ok(new Error msg)

					locals.templates.push
						path : tmplPath
						type : types[type]
						id   : path.basename(tmplPath, ".#{type}")
							.replace(/_/g, '-') + '-tmpl'
					do ok
			], (err) -> next(err, fn, locals)

		(fn, locals, next) ->
			try code = fn(locals)
			catch error
				return next(error)

			next(null, code)

		(code, done) ->
			fs.writeFile opath, code, done
	], done
]

builders['requirejs_config.json'] = ['.js', (ipath, opath, dev, done) ->
	async.waterfall [
		(next) -> fs.readFile ipath, 'utf-8', next
		(code, next) ->
			code = code.trim()
			if dev
				code.replace /\}\s*$/, '"bust=" + new Date().getTime()\n}'

			code = "require.config(#{code});\n\n"
			code += if dev
				"""
					define(['libs/tmpl_loader'], function(load) {
						load(require.bind(null, ['main']));
					});\n
				"""
			else "define(['main'], null);\n"

			next null, code
		(code, done) ->
			fs.writeFile opath, code, done
	], done
]

builders['.jade'] = ['', (ipath, opath, dev, done) ->
	async.waterfall [
		(next) -> fs.readFile ipath, 'utf-8', next
		(code, next) ->
			[err, fn] = compileJade ipath, code
			next err if err
			try code = fn()
			catch error
				return next error

			next null, code
		(code, done) ->
			fs.writeFile opath, code, done
	], done
]

builders['.less'] = ['.css', (ipath, opath, dev, done) ->
	async.waterfall [
		(next) -> fs.readFile ipath, 'utf-8', next
		(code, next) ->
			try
				less.render code,
					filename : ipath
					paths    : [path.dirname ipath]
					optimization : if dev then 0 else 2
				, next
			catch error
				return next error
		(code, done) ->
			fs.writeFile opath, code, done
	], done
]

builders['.coffee'] = ['.js', (ipath, opath, dev, done) ->
	async.waterfall [
		(next) -> fs.readFile ipath, 'utf-8', next
		(code, next) ->
			[err, code] = compileCoffee ipath, code
			return next err if err

			try code = makeAMD code
			catch error
				return next error

			next null, code
		(code, done) ->
			fs.writeFile opath, code, done
	], done
]

builders['.json'] = ['.js', (ipath, opath, dev, done) ->
	async.waterfall [
		(next) -> fs.readFile ipath, 'utf-8', next
		(code, next) ->
			try code = makeAMD code, yes
			catch error
				return next error

			next null, code
		(code, done) ->
			fs.writeFile opath, code, done
	], done
]

builders['*'] = (ipath, opath, dev, done) ->
	clone ipath, opath, done

preparers = {}
preparers['knockout'] = (ipath, opath, dev, done) ->
	clone(
		"#{ipath}/build/output/knockout-latest.debug.js",
		"#{opath}/index.js", done
	)

preparers['requirejs'] = (ipath, opath, dev, done) ->
	clone "#{ipath}/require.js", "#{opath}/index.js", done

preparers['requirejs-domready'] = (ipath, opath, dev, done) ->
	clone "#{ipath}/domReady.js", "#{opath}/index.js", done

preparers['bootswatch'] = (ipath, opath, dev, done) ->
	async.parallel [
		async.apply async.waterfall, [
			(next) ->
				fs.readFile "#{ipath}/simplex/bootstrap.css", 'utf-8', next
			(code, next) ->
				code = code.replace(/\.{2}\/img\//g, 'img/')
				fs.writeFile "#{opath}/index.css", code, next
		]

		async.apply clone, "#{ipath}/img", "#{opath}/img"
	], done

preparers['bintrees'] = (ipath, opath, dev, done) ->
	mkdir "#{opath}/lib", (err) ->
		done err if err
		async.forEach ['lib/bintree', 'lib/rbtree',
		               'lib/treebase', 'index'], (name, ok) ->
			fs.readFile "#{ipath}/#{name}.js", 'utf-8', (err, content) ->
				ok err if err

				fs.writeFile "#{opath}/#{name}.js", makeAMD(content), ok
		, done

################################################################################
caseChange = /([a-z])([A-Z])/g
String::toPathName = ->
	@replace(caseChange, '$1_$2').toLowerCase()

validName = /^[a-zA-Z_$][\w$]+$/
String::isValidName = (str) ->
	validName.test str

className = /^[A-Z_$][\w$]+$/
String::isClassName = (str) ->
	className.test str

Function::only = (num) ->
	return => this Array::slice.call(arguments, 0, num)...

mkdir = (dpath, done) -> exec "mkdir -p #{dpath}", done.only 1
clear = (dpath, done) -> exec "rm -rf #{dpath}/*", done.only 1
clone = (f, to, done) -> exec "cp -R #{f} #{to}",  done.only 1
touch = (fpath, done) -> exec "touch #{fpath}",    done.only 1

download = (url, fpath, done) ->
	if arguments.length == 3
		exec "curl -o #{fpath} #{url}", done.only 1
	else
		exec "curl #{url}", done.only 2

# decorator
# see https://github.com/joyent/node/issues/2054
blocked = {}
wch = (dpath, fn) -> (event, name) ->
	fpath = "#{dpath}/#{name}"
	if fpath of blocked
		fns = blocked[fpath]
		return if fn in fns
		fns.push fn
	else
		fns = blocked[fpath] = [fn]

	setTimeout ->
		fns.splice fns.indexOf(fn), 1
		delete blocked[fpath] if fns.length == 0
	, 25

	fn event, fpath

watch = (dpath, iterator, fallback) ->
	done = (err) -> fallback(err) if err
	fs.watch dpath, wch dpath, (event, fpath) ->
		async.waterfall [
			(next) -> fs.exists fpath, (exist) ->
				if exist
					next null
				else
					iterator 'remove', fpath, done
			(next) -> fs.lstat fpath, next
			(stat) ->
				if stat.isDirectory()
					recurWatch fpath, iterator, fallback if event is 'rename'
				else
					iterator event, fpath, done
		], done

recurWatch = (dpath, iterator, fallback) ->
	watch(dpath, iterator, fallback)

	recurReaddir dpath, (fpath, stat) ->
		watch(fpath, iterator, fallback) if stat.isDirectory()

recurLook = (dpath, iterator, done) ->
	recurReaddir dpath, (fpath, stat, cmpl) ->
		if stat.isDirectory() then do cmpl else iterator fpath, cmpl
	, done

recurReaddir = (dpath, iterator, done) ->
	fs.readdir dpath, (err, files) ->
		return done(err) if err
		async.forEach files, (fname, cmpl) ->
			fpath = path.join dpath, fname
			fs.lstat fpath, (err, stat) ->
				return cmpl(err) if err
				if stat.isDirectory()
					iterator fpath, stat, ((err) -> cmpl(err) if err)
					recurReaddir(fpath, iterator, cmpl)
				else iterator fpath, stat, cmpl
		, done

aliasSep  = /\s+as\s+/i
rightName = /^[a-zA-Z_$][\w$]*$/
# * (code, [imports], [exports]) ->
# * (code, woFactory) ->
makeAMD = (code, args...) ->
	return "define(#{code.trim()});\n" if args[0] is true

	[imports, exports] = args
	data = ['define(function(require, exports, module) {']

	if imports?
		for imp in imports
			[pathModule, alias] = imp.split(aliasSep)
			alias ?= path.basename(pathModule, path.extname pathModule)
			unless ~alias.search rightName
				throw new Error "Bad import alias (#{alias})"
			data.push "var #{alias} = require(#{pathModule});"

	data.push code

	if exports?
		if Array.isArray(exports)
			for exp in exports
				[what, alias] = exp.split(aliasSep)
				alias ?= what
				for part in alias.split '.' when !~part.search rightName
					throw new Error "Bad export alias (#{alias})"
				data.push "exports.#{alias} = #{what};"
		else
			data.push "module.exports = #{exports};"

	data.push '});\n'
	data.join '\n'

makeSandbox = (code) ->
	"!function() {\n#{code}\n}\n"