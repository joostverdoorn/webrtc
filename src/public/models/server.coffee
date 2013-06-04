define [
	'socket.io/socket.io'
	], ( ) ->

	# This class is a model for the server, and provides all interaction with 
	# the actual server.
	#

	class Server

		# Constructs a new server model. 
		#
		# @param _address [String] the address of the server to which to connect.
		#
		constructor: ( @_address ) ->
			@_socket = io.connect(@_address)

			@_socket.on('connect', @onConnect)
			@_socket.on('pong', @onPong)

		# Pings the server. A callback function should be provided to do anything
		# with the ping.
		#
		# @param callback [Function] the callback to be called when a pong was received.
		#
		ping: ( callback ) ->
			@_pingStart = App.time()
			@_pingCallback = callback
			@_socket.emit('ping')

		on: ( event, callback ) ->
			@_socket.on(event, callback)

		emit: ( event, args... ) ->
			args = [event].concat(args)
			@_socket.emit.apply(@_socket, args)

		sendTo: ( receiver, event, args... ) ->
			args = ['sendTo', receiver, event].concat(args)
			@emit.apply(@, args)

		# Is called when a ping is received. We just emit 'pong' back to the client.
		#
		onPing: ( ) ->
			@_socket.emit('pong')

		# Is called when a pong is received. We call the callback function defined in 
		# ping with the amount of time that has elapsed.
		#
		onPong: ( ) =>
			@_latency = App.time() - @_pingStart
			@_pingCallback(@_latency, packet)
			@_pingStart = undefined

		# Is called when a connection is made. We emit our type to the server.
		# 
		onConnect: ( ) =>
			console.log 'connected to server'
			@_socket.emit('type.set', App.type)
			App.id = @_socket.socket.sessionid
			$('body').append(App.id)

		
