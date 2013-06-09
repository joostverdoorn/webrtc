define [
	'helpers/mixable'
	'helpers/mixin.eventbindings'
	'socket.io/socket.io'
	], ( Mixable, EventBindings ) ->

	# This class is a model for the server, and provides all interaction with 
	# the actual server.
	#

	class Server extends Mixable

		@concern EventBindings

		# Constructs a new server model. 
		#
		# @param _address [String] the address of the server to which to connect.
		#
		constructor: ( @_address ) ->
			@_socket = io.connect(@_address)

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
			@_socket.emit('type.set', App.type)
			App.id = @_socket.socket.sessionid
			$('.id').html(App.id)

		
