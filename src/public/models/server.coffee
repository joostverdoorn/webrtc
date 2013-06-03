define [
	'socket.io/socket.io'
	], ( ) ->

	class Server
		constructor: ( @_address ) ->
			@_socket = io.connect(@_address)
			@_socket.on('connect', @onConnect)
			@_socket.on('pong', @onPong)

		ping: ( callback ) ->
			@_pingStart = App.time()
			@_pingCallback = callback
			@_socket.emit('ping')

		pong: ( ) ->
			@_socket.emit('pong')

		onPong: ( ) =>
			@_latency = App.time() - @_pingStart
			@_pingCallback(@_latency, packet)
			@_pingStart = undefined

		onConnect: ( ) =>
			console.log 'connected to server'
			@_socket.emit('type.set', App.type)