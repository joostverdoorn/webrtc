define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'
	
	'socket.io'
	], ( Mixable, EventBindings, io ) ->

	# This class is a model for the server, and provides all interaction with 
	# the actual server.
	#

	class Server extends Mixable

		@concern EventBindings

		# Constructs a new server model. 
		#
		# @param _address [String] the address of the server to which to connect.
		#
		constructor: ( @node, @_address ) ->
			@_socket = io.connect(@_address, {'force new connection': true})
			@on('event.bind', ( name ) =>
				if @_socket.listeners(name).length > 0
					return

				@_socket.on(name, ( args... ) =>
					args = [name].concat(args)
					@trigger.apply(@, args)
				)
			)

			@on('event.unbind', ( name ) ->
				@_socket.removeAllListeners(name)
			)
			
			@on('connect', @_onConnect)
			@on('ping', @_onPing)
			@on('pong', @_onPong)

		# Emits to the server.
		#
		# @param event [String] the event to be emitted
		# @param args... [Any] the arguments to be emitted
		#
		emit: ( event, args... ) ->
			@_socket.emit.apply(@_socket, arguments)

		# Disconnects the WebSocket connection.
		#
		disconnect: ( ) ->
			@_socket.disconnect()

		# Requests information from the server.
		#
		# @param request [String] the string identifier of the information request
		# @param callback [Function] the callback to be called once the information is received
		# @param args... [Any] the arguments to be passed along with the request
		#
		requestInfo: ( request, callback, args... ) ->
			requestID = _.uniqueId('request')
			@once(requestID, callback)

			args = ['info.request', request, requestID].concat(args)
			@emit.apply(@, args)

		# Sends a message to a peer, via the server.
		#
		# @param receiver [String] the id of the receiving client
		# @param event [String] the event to send
		# @param args... [Any] any paramters you may want to pass
		#
		sendTo: ( receiver, event, args... ) ->
			args = ['sendTo', receiver, event].concat(args)
			@emit.apply(@, args)

		# Pings the server. A callback function should be provided to do anything
		# with the ping.
		#
		# @param callback [Function] the callback to be called when a pong was received.
		#
		ping: ( callback ) ->
			@_pingStart = App.time()
			@_pingCallback = callback
			@emit('ping')

		# Is called when a ping is received. We just emit 'pong' back to the server.
		#
		_onPing: ( ) =>
			@emit('pong')

		# Is called when a pong is received. We call the callback function defined in 
		# ping with the amount of time that has elapsed.
		#
		_onPong: ( ) =>
			@_latency = App.time() - @_pingStart
			@_pingCallback?(@_latency)
			@_pingStart = undefined

		# Is called when a connection is made. We emit our type to the server.
		# 
		_onConnect: ( ) =>
			console.log 'connected to server'
			@_socket.emit('type.set', @node.type)
			@node.id = @_socket.socket.sessionid
			$('.id').html(@node.id)



		
