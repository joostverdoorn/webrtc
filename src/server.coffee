define [
	'public/library/models/remote.client'

	'public/library/models/message'
	'public/library/models/collection'
	'public/library/helpers/listener'

	'express'
	'http'
	'socket.io'
	'underscore'
	], ( Node, Message, Collection, Listener, express, http, io, _ ) ->


	# Server class. This is run on the server and maintains connections to
	# any client: masters or slaves.

	class Server

		id: 'server'

		queryTimeout: 5000

		# Constructs a new server.
		#
		constructor: ( dir ) ->
			@_initTime = Date.now()

			@queries = new Listener()
			@_nodes = new Collection()
			@_nodes.on('disconnect', ( node ) => @removeNode(node))

			@onQuery
				'ping': ( callback ) =>
					callback 'pong', @time()
				'nodes': ( callback, type, extensive = false ) =>
					unless extensive
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

			@_app = express()
			@_server = http.createServer(@_app)
			@_io = io.listen(@_server, log: false)
			@_io.sockets.on('connection', @login)

			# Serve static content from ./public/library
			@_app.configure =>
				@_app.use(express.static("#{dir}/public"))

			# Redirect a controller url for lees typing
			@_app.get('/controller/:nodeID', ( req, res ) =>
				res.redirect('/controller.html?nodeID=' + req.params.nodeID)
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

		# Binds a query.
		#
		# @overload on(name, callback, context = null)
		#	 Binds a single event.
		# 	 @param name [String] the event name to bind
		# 	 @param callback [Function] the callback to call
		# 	 @param context [Object] the context of the binding
		#
		# @overload on(bindings)
		#	 Binds multiple events.
		#	 @param bindings [Object] an object mapping event names to functions
		#
		onQuery: ( args... ) ->
			@queries.on.apply(@queries, args)

		# Attempts to emit a message to a node by id.
		#
		# @overload emitTo( to, event, args... )
		# 	 Convenient way to send a message to a peer by id.
		# 	 @param to [String] the id of the peer to pass the message to
		#	 @param event [String] the event to pass to the peer
		# 	 @param args... [Any] any other arguments to pass along
		#
		# @overload emitTo( params )
		# 	 More advanced way that allows for specifying ttl and route.
		#	 @param params [Object] an object containing params
		#	 @option params to [String] the id of the peer to pass the message to
		#	 @option params event [String] the event to pass to the peer
		# 	 @option params args [Array<Any>] any other arguments to pass along
		#	 @option params path [Array] the route the message should take
		# 	 @option params ttl [Integer] the number of hops the message may take
		#
		emitTo: ( ) ->
			params = {}

			if typeof arguments[0] is 'string'
				to 	  = arguments[0]
				event = arguments[1]
				args  = Array::slice.call(arguments, 2)

			else if typeof arguments[0] is 'object'
				to 		= arguments[0].to
				event 	= arguments[0].event
				args 	= arguments[0].args ? []

				params.path = arguments[0].path
				params.ttl  = arguments[0].ttl

			message = new Message(to, @id, @time(), event, args, params)
			@relay(message)

		# Relays a composed message to a certain node.
		#
		# @param message [Message] the message to relay
		#
		relay: ( message ) ->
			if node = @getNode(message.to)
				node.send(message)

		# Returns the time that has passed since the starting of the server.
		#
		# @return [Integer] the amount of milliseconds that has elapsed.
		#
		time: ( ) ->
			return Date.now() - @_initTime
