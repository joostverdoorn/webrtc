requirejs = require('requirejs')

requirejs.config
	# Pass the top-level main.js/index.js require
	# function to requirejs so that node modules
	# are loaded relative to the top-level JS file.
	nodeRequire: require

	shim: 
		'underscore': 
			exports: '_'

requirejs [
	'models/client.master'
	'models/client.slave'

	'express'
	'http'
	'socket.io'
	'underscore'
	], ( Master, Slave, express, http, io, _ ) ->


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
						master = new Master(socket)					
						@addClient(master)
					when 'slave'
						slave = new Slave(socket)
						@addClient(slave)
			)

		# Adds a client to the client list (either master or slave list) 
		#
		# @param client [Client] the client to add
		#
		addClient: ( client ) ->
			if client instanceof Master
				@_masters[client.id] = client
			else if client instanceof Slave
				@_slaves[client.id] = client

		# Removes a client from the client list (either master or slave list) 
		#
		# @param client [Client] the client to remove
		#
		removeClient: ( client ) ->
			if @_masters[client.id]?
				delete @_masters[client.id]
			else if @_slaves[client.id]?
				delete @_slaves[client.id]

		# Returns the time that has passed since the starting of the server.
		#
		# @return [Integer] the amount of milliseconds that has elapsed.
		#
		time: ( ) ->
			return Date.now() - @_initTime

		# Returns an array of all connected masters.
		#
		# @return [Array<Master>] an array containing all connected masters
		#
		getMasters: ( ) ->
			return @_masters

		# Returns a certain master
		#
		# @param id [String] the id of the master
		# @return [Slave] the master
		#
		getMaster: ( id ) ->
			return @getMasters()[id]

		# Returns an array of all connected slaves.
		#
		# @return [Array<Slave>] an array containing all connected slaves
		#
		getSlaves: ( ) ->
			return @_slaves

		# Returns a certain slave
		#
		# @param id [String] the id of the slave
		# @return [Slave] the slave
		#
		getSlave: ( id ) ->
			return @getSlaves()[id]

		# Returns an array of all connected clients.
		#
		# @return [Array<Client>] an array containing all connected clients
		#
		getClients: ( ) ->
			return _.extend({}, @getMasters(), @getSlaves()) 

		# Returns a certain client
		#
		# @param id [String] the id of the client
		# @return [Client] the client
		#
		getClient: ( id ) ->
			return @getClients()[id]
		
	global.Server = new Server()
