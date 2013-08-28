#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'library/controller'
	'library/models/remote.client'

	'library/models/message'
	'library/helpers/collection'

	'express'
	'http'
	'socket.io'
	'underscore'
	], ( Controller, Node, Message, Collection, express, http, io, _ ) ->


	# Server class. This is run on the server and maintains connections to
	# any client: masters or slaves.

	class Server extends Controller

		id: 'server'
		type: 'server'

		# Constructs a new server.
		#
		initialize: ( dir ) ->
			@_initTime = Date.now()

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

		# # Relays a composed message to a certain node.
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
