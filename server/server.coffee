connect      = require 'connect'
path         = require 'path'
passport     = require 'passport'
SessionStore = require('connect-mongo')(connect)

auth = require './auth'

app = connect()
	.use(connect.logger 'dev')
	.use(connect.cookieParser())
	.use(connect.bodyParser())
	.use(connect.methodOverride())
	.use(connect.session {
		store  : new SessionStore db : 'sessions'
		secret : Math.random().toString(36)[2..]
	})
	.use(passport.initialize())
	.use(passport.session())
	.use(connect.static path.join __dirname, '../public')

isAuthorization = (fn) -> (req, res, next) ->
	return unless req.method == 'POST'

	unless req.body.username
		res.writeHead 401, 'Unknown user'
		return do res.end

	unless req.body.password
		res.writeHead 401, 'Invalid password'
		return do res.end

	fn req, res, next

ensureAuthenticated = (fn) -> (req, res, next) ->
	if req.isAuthenticated()
		return fn req, res, next

	res.statusCode = 403
	do res.end

app.use '/login', isAuthorization (req, res, next) ->
	passport.authenticate('local', (err, user, info) ->

		if info instanceof auth.UnknownUserError
			res.writeHead 401, 'Unknown user'
		else if info instanceof auth.InvalidPasswordError
			res.writeHead 401, 'Invalid password'
		else if user?
			res.statusCode = 200
		else
			return do next

		if res.statusCode == 200
			req.logIn user, (err) ->
				next err if err
				do res.end
		else
			do res.end

	)(req, res, next)

app.use '/signup', isAuthorization (req, res, next) ->
	auth.register req.body.username, req.body.password, (err) ->

		if err instanceof auth.ExistingUserError
			res.writeHead 401, 'Existing user'
		else
			res.statusCode = 200

		do res.end

app.use '/logout', (req, res, next) ->
	do req.logout
	res.statusCode = 200
	do res.end

app.listen 3000