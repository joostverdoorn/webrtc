express = require('express')
http = require('http')

Model = require('./models')

class Server

	constructor: ( ) ->
		@_masters = []

		@_app = express()
		@_server = http.createServer(@_app)
		
		# Serve static content from ./public
		@_app.configure =>
			@_app.use(express.static("#{__dirname}/public"))
			
		@_server.listen(8080)		
		
module.exports = new Server()
