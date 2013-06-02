express = require('express')
http = require('http')


class Server

	constructor: ( ) ->
		@_app = express()
		@_server = http.createServer(@_app)
		
		# Server static content from ./public
		@_app.configure =>
			@_app.use(express.static("#{__dirname}/public"))
			
		@_server.listen(8080)		
		
module.exports = new Server()


alert "jasdasdoasso"
