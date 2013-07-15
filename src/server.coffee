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
	'public/models/remote.client'
	'public/models/collection'

	'express'
	'http'
	'socket.io'
	'underscore'
	], ( Node, Collection, express, http, io, _ ) ->


	# Server class. This is run on the server and maintains connections to 
	# any client: masters or slaves.

	class Server

		# Constructs a new server.
		#
		constructor: ( ) ->
			@_initTime = Date.now()

			@_nodes = new Collection()

			@_app = express()
			@_server = http.createServer(@_app)
			@_io = io.listen(@_server)
			@_io.sockets.on('connection', @login)
			
			# Serve static content from ./public
			@_app.configure =>
				@_app.use(express.static("#{__dirname}/public"))

			@_app.get('/nodes', ( req, res ) =>
				nodes = @getNodes()

				res.writeHead(200, 'Content-Type': 'application/json')
				i = 0
				result = {}
				console.log nodes.length
				if nodes.length is 0
					res.write '[]'
					res.end()

				requestDone = false

				setTimeout(=>
						unless requestDone
							res.write JSON.stringify({
									error: 'ERR_TIMEOUT'
								})
							requestDone = true
					, 5000);

				for node in nodes
					( (node) ->
						node.query('peers', ( peers ) ->
							result[node.id] = {
								peers: peers
								isSuperNode: node.isSuperNode
								benchmark: node.benchmark
								system: node.system
								latency: node.latency
							}

							i++

							if i is nodes.length and not requestDone
								requestDone = true
								res.write(JSON.stringify(result))
								res.end()
						)
					) ( node )
			)
				
			@_server.listen(8080)

		# Defines a login process for a socket. Further input from the client
		# is required to finalize this process, and so we bind a function on
		# the event 'type.set' so we can create a new Master or Slave client.
		#
		# @param socket [WebSocket] the socket for which to start the login.
		#
		login: ( socket ) =>
			node = new Node(@, socket)
			@addNode(node)

			node.on('disconnect', ( ) =>
				@removeNode(node)
			)

		# Sends a message to a certain node.
		#
		# @param to [String] the id of the node to pass the message to
		# @param event [String] the event to pass to the node 
		# @param args... [Any] any arguments to pass along 
		#
		emitTo: ( to, event, args... ) ->
			message = new Message(to, null, event, args)	
			@relay(message)

		# Relays a composed message to a certain node.
		#
		# @param message [Message] the message to relay
		#
		relay: ( message ) ->
			if node = @getNode(message.to)
				node.send(message)

		# Adds a node to the node list
		#
		# @param node [Node] the node to add
		#
		addNode: ( node ) ->
			@_nodes.add(node)

		# Removes a node from the node list
		#
		# @param node [Node] the node to remove
		#
		removeNode: ( node ) ->
			@_nodes.remove(node)

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

		# Responds to a request
		#
		# @param request [String] the string identifier of the request
		# @param args... [Any] any arguments that may be accompanied with the request
		# @return [Object] a response to the query
		#
		query: ( request, args... ) ->
			switch request
				when 'ping'
					return 'pong'
				when 'nodes' 
					nodes = (node.serialize() for node in @getNodes())		
					return nodes

		# Returns the time that has passed since the starting of the server.
		#
		# @return [Integer] the amount of milliseconds that has elapsed.
		#
		time: ( ) ->
			return Date.now() - @_initTime



	global.Server = new Server()
