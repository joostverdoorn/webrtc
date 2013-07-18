define [
	'public/models/remote._'

	'underscore'
	], ( Remote, _ ) ->

	class Remote.Client extends Remote

		# Initializes this class. Accepts a socket connection and binds to events.
		# Is called from the baseclass' constructor.
		#
		# @param _connection [Socket.IO] the socket connection
		#
		initialize: ( @_connection ) ->
			@id = @_connection.id

			@_connection.on('message', ( message ) => @trigger('message', message))
			@_connection.on('disconnect', ( ) => @trigger('disconnect'))

			@on('setSuperNode', @_onSetSuperNode)

			@query('benchmark', ( benchmark ) => @benchmark = benchmark)
			@query('system', ( system ) => @system = system)
			@query('isSuperNode', ( isSuperNode ) => @isSuperNode = isSuperNode)


		# Disconnects from the client.
		#
		disconnect: ( ) ->
			@_connection.disconnect()

		# Returns wether or not this peer is connected.
		#
		# @return [Boolean] wether or not this peer is connected
		#
		isConnected: ( ) ->
			return @_connection.socket.connected

		# Sends a predefined message to the remote.
		#
		# @param message [Message] the message to send
		#
		_send: ( message ) ->
			@_connection.emit('message', message.serialize()) 

		# Is called when a SuperNode state is changed
		#
		# @param name [String] the event that's unbound
		#
		_onSetSuperNode: (isSuperNode) =>
			@isSuperNode = isSuperNode

		# Serialize a node object to send to new nodes. Is called from the server
		#
		serialize: () ->
			node = new Object()
			node.id = @id
			node.system = @system
			node.benchmark = @benchmark
			node.isSuperNode = @isSuperNode
			return node