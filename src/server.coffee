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
	'models/node'

	'express'
	'http'
	'socket.io'
	'underscore'
	], ( Node, express, http, io, _ ) ->


	# Server class. This is run on the server and maintains connections to 
	# any client: masters or slaves.

	class Server

		# Constructs a new server.
		#
		constructor: ( ) ->
			@_initTime = Date.now()

			@_nodes = []

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
			node = new Node(socket)
			@addNode(node)

		# Adds a node to the node list
		#
		# @param node [Node] the node to add
		#
		addNode: ( node ) ->
			@_nodes.push(node)

		# Removes a node from the node list
		#
		# @param node [Node] the node to remove
		#
		removeNode: ( node ) ->
			@_nodes = _(@_nodes).without(node)

		# Returns a node specified by an id
		#
		# @param id [String] the id of the requested node
		# @return [Node] the node
		#
		getNode: ( id ) ->
			return _(@_nodes).find( ( node ) -> node.id is id )

		# Returns an array of connected nodes.
		#
		# @param type [String] the type by which to filter the nodes
		# @return [Array<Node>] an array containing all connected peers
		#
		getNodes: ( type = null ) ->
			if type?
				return _(@_nodes).filter( ( node ) -> node.type is type )
			else
				return @_nodes

		# Returns the time that has passed since the starting of the server.
		#
		# @return [Integer] the amount of milliseconds that has elapsed.
		#
		time: ( ) ->
			return Date.now() - @_initTime

	global.Server = new Server()
