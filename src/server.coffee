define [
	'public/library/models/remote.client'
	'public/library/models/collection'
	'public/library/models/message'

	'express'
	'http'
	'socket.io'
	'underscore'
	], ( Node, Collection, Message, express, http, io, _ ) ->


	# Server class. This is run on the server and maintains connections to
	# any client: masters or slaves.

	class Server

		id: 'server'

		queryTimeout: 5000

		# Constructs a new server.
		#
		constructor: ( dir ) ->
			@_initTime = Date.now()

			@_nodes = new Collection()
			@_nodes.on('disconnect', ( node ) => @removeNode(node))

			@_app = express()
			@_server = http.createServer(@_app)
			@_io = io.listen(@_server, log: false)
			@_io.sockets.on('connection', @login)

			# Serve static content from ./public/library
			@_app.configure =>
				@_app.use(express.static("#{dir}/public"))

			# Redirect a controller url for lees typing
			@_app.get('/controller/:nodeId', ( req, res ) =>
				res.redirect('/controller.html?nodeId=' + req.params.nodeId)
				res.end()
			)

			@messageStorage = []
			@partialMessages = {}

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

		# Responds to a request
		#
		# @param request [String] the string identifier of the request
		# @param args... [Any] any arguments that may be accompanied with the request
		# @param callback [Function] the callback to call with the response
		#
		query: ( request, args..., callback ) ->
			switch request
				when 'ping'
					callback 'pong', @time()
				when 'nodes'
					type = args[0]
					extensive = args[1]

					unless extensive?
						nodes = (node.serialize() for node in @getNodes(type))
						callback nodes
					else
						nodes = @getNodes(type)
						nodesInfo = []
						i = 0
						for node in nodes
							( ( node ) ->
								node.query('info', ( info ) =>
									if info?
										nodesInfo.push(info)
									if ++i is nodes.length
										callback(nodesInfo)
								)
							) ( node )
				else
					callback null

		# Returns the time that has passed since the starting of the server.
		#
		# @return [Integer] the amount of milliseconds that has elapsed.
		#
		time: ( ) ->
			return Date.now() - @_initTime
