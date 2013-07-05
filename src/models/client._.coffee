define [ 
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'underscore'
	], ( Mixable, EventBindings, _ ) ->
		
	# This abstract class provides websocket connections for masters and slaves
	#

	class Client extends Mixable

		@concern EventBindings

		# Constructs a new client.
		#
		# @param _socket [WebSocket] the socket that represents the client
		#
		constructor: ( @_socket ) ->
			@id = @_socket.id

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

			@on('disconnect', @_onDisconnect)
			@on('sendTo', @_onSendTo)
			@on('ping', @_onPing)
			@on('pong', @_onPong)
			@on('requestInfo', @_onRequestInfo)

			@initialize()

		# This method is called when the constructor has finished running. It should be
		# overridden by any subclass.
		#
		initialize: ( ) ->

		# Kills our socket connection. The handler on the 'disconnect' event (_onDisconnect)
		# will remove this client from the server.
		#
		die: ( ) ->
			if @_socket.socket.connected
				@_socket.disconnect()

		# Emits to the client.
		#
		# @param event [String] the event to be emitted
		# @param args... [Any] the arguments to be emitted
		#
		emit: ( event, args... ) ->
			args = [event].concat(args)
			@_socket.emit.apply(@_socket, args)


		# Pings the client. A callback function should be provided to do anything
		# with the ping.
		#
		# @param callback [Function] the callback to be called when a pong was received.
		#
		ping: ( callback ) ->
			@_pingStart = Server.time()
			@_pingCallback = callback
			@emit('ping')	

		# Is called when a ping is received. We just emit 'pong' back to the client.
		#
		_onPing: ( ) =>
			@emit('pong')

		# Is called when a pong is received. We call the callback function defined in 
		# ping with the amount of time that has elapsed.
		#
		_onPong: ( ) =>
			@_latency = Server.time() - @_pingStart
			@_pingCallback?(@_latency)
			@_pingStart = undefined

		# Is called when a sendTo event is received. Will forward the event and arguments
		# to the intended receiver.
		#
		# @param receiver [String] a string representing the receiver
		# @param event [String] the event to be emitted
		# @param args... [Any] the arguments to be emitted
		#
		_onSendTo: ( receiver, event, args... ) ->
			args = [event, @id].concat(args)

			client = Server.getClient(receiver)
			client?.emit.apply(client, args)

		# Is called when the socket disconnects. Will remove this client from the server list.
		#
		_onDisconnect: ( ) =>
			Server.removeClient(@)
		
		_onRequestInfo: ( request, requestID, args... ) ->
			switch request
				when 'masters'
					@emit(requestID, _(Server.getMasters()).keys())
				when 'slaves'
					@emit(requestID, _(Server.getSlaves()).keys())
				when 'clients'
					@emit(requestID, _(Server.getClients()).keys())