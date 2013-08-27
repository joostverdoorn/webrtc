#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'library/models/remote._'
	'library/models/message'

	'socket.io'
	'underscore'
	], ( Remote, Message, io, _ ) ->

	# The central server, as seen from a p2p node
	class Remote.Server extends Remote

		id: 'server'

		# Initializes this class. Will connect to a remote server using sockets.
		# Is called from the baseclass' constructor.
		#
		# @param _address [String] the address of the server to connect to
		#
		initialize: ( @_address ) ->
			@connect()
			@on('connect', @_onConnect)

		# Connects to the server using websockets.
		#
		connect: ( ) ->
			@_connection = io.connect(@_address, {'force new connection': true})

			@_connection.on('message', ( message ) => @trigger('message', Message.deserialize(message)))
			@_connection.on('connect', ( ) => @trigger('connect', @_connection.socket.sessionid))
			@_connection.on('disconnect', ( ) => @trigger('disconnect'))

		# Disconnects from the server.
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
		# @private
		_send: ( message ) ->
			@_connection.emit('message', message.serialize())

		# Is called when a connection is made. We emit our type to the server.
		# @private
		_onConnect: ( ) =>
			console.log 'connected to server'
