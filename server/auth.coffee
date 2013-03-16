passport      = require 'passport'
mongo         = require 'mongodb'
async         = require 'async'
LocalStrategy = require('passport-local').Strategy

users = null

host = process.env['MONGO_NODE_DRIVER_HOST'] ? 'localhost'
port = process.env['MONGO_NODE_DRIVER_PORT'] ? mongo.Connection.DEFAULT_PORT

db = new mongo.Db('data', new mongo.Server(host, port, {}), {w : 1})
db.open (err, db) ->
	throw err if err?
	users = new mongo.Collection db, 'users'

passport.serializeUser (user, done) ->
	done null, user._id

passport.deserializeUser (strID, done) ->
	id = mongo.ObjectID strID

	users.find({ _id : id }).nextObject (err, user) ->
		return done err if err?
		
		if user?
			done null, user
		else
			done new UnknownUserError

passport.use new LocalStrategy (username, password, done) ->
	exports.authenticate username, password, (err, user) ->
		unless err
			done null, user
		else if err instanceof AuthError
			done null, null, err
		else
			done err

exports.AuthError = class AuthError extends Error
	constructor : -> super # fix extending Error (CS 1.6)
exports.InvalidPasswordError = class InvalidPasswordError extends AuthError
exports.UnknownUserError = class UnknownUserError extends AuthError
exports.ExistingUserError = class ExistingUserError extends AuthError

exports.authenticate = (username, password, done) ->
	users.find({username}).nextObject (err, user) ->
		return done err if err?

		unless user?
			return done new UnknownUserError

		if user.password == password
			done null, user
		else
			done new InvalidPasswordError

exports.register = (username, password, done) ->
	async.waterfall [
		(next) ->
			users.find({username}).nextObject next
		(user, next) ->
			next if user? then new ExistingUserError else null
		(next) ->
			users.insert { username, password }, { safe : yes }, next
	], done
