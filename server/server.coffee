connect = require 'connect'
path    = require 'path'

app = connect()
	.use(connect.logger 'dev')
	.use(connect.static path.join __dirname, '../public')
	.listen 3000