express = require('express')
http = require('http')
io = require('socket.io')
_ = require('underscore')._

Model = require('./models')


# Server class. This is run on the server and maintains connections to 
# any client: masters or slaves.

class Server

	# Constructs a new server.
	#
	constructor: ( ) ->
		@_initTime = Date.now()

		@_masters = {}
		@_slaves = {}

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
					@_master = new Model.Client.Master(socket)					
					@_masters[socket.id] = @_master
				when 'slave'
					@_slave = new Model.Client.Slave(socket)
					@_slaves[socket.id] = @_slave
					if @_master then @_slave.emit('master.add', @_master.id)
		)

	# Returns the time that has passed since the starting of the server.
	#
	# @return [Integer] the amount of milliseconds that has elapsed.
	#
	time: ( ) ->
		return Date.now() - @_initTime

	# Returns a certain client
	#
	# @param id [String] the id of the client
	#
	getClient: ( id ) ->
		return _.extend({}, @_masters, @_slaves)[id]
		
global.Server = new Server()
