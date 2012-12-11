express = require 'express'
path    = require 'path'

app = express()

app.configure ->
	app.use do express.methodOverride
	app.use do express.bodyParser
	app.use app.router

app.configure 'development', ->
	app.use express.static path.join __dirname, '../public'
	app.use express.errorHandler
		dumpExceptions : on
		showStack      : yes

app.listen 3000