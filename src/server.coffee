express = require('express')
http = require('http')
io = require('socket.io')

Model = require('./models')


# Server class. This is run on the server and maintains connections to 
# any client: masters or slaves.

class Server

	# Constructs a new server.
	#
	constructor: ( ) ->
		@_initTime = Date.now()

		@_masters = []
		@_slaves = []

		@_app = express()
		@_server = http.createServer(@_app)
		@_io = io.listen(@_server)
		@_io.sockets.on('connection', @login)
		
		# Serve static content from ./public
		@_app.configure =>
			@_app.use(express.static("#{__dirname}/public"))
			
		@_server.listen(8080)

	# Defines a login process for a socket. Further input from the client
	# is required to finalize this process, and so we bind a function on
	# the event 'type.set' so we can create a new Master or Slave client.
	#
	# @param socket [WebSocket] the socket for which to start the login.
	#
	login: ( socket ) =>
		socket.on('type.set', ( type ) => 
			switch type
				when 'master'
					@_masters.push(new Model.Client.Master(socket))
				when 'slave'
					@_slaves.push(new Model.Client.Slave(socket))
		)

	# Returns the time that has passed since the starting of the server.
	#
	# @return [Integer] the amount of milliseconds that has elapsed.
	#
	time: ( ) ->
		return Date.now() - @_initTime
		
global.Server = new Server()
