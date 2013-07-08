define [
	'public/models/remote._'

	'socket.io'
	'underscore'
	], ( Remote, io, _ ) ->

	class Remote.Server extends Remote

		# Initializes this class. Will connect to a remote server using sockets.
		# Is called from the baseclass' constructor.
		#
		# @param _address [String] the address of the server to connect to
		#
		initialize: ( @_address ) ->
			@connect()

			@on('event.bind', @_onEventBind)
			@on('event.unbind', @_onEventUnbind)
			@on('connect', @_onConnect)	

		# Connects to the server using websockets.
		#
		connect: ( ) ->
			@_connection = io.connect(@_address, {'force new connection': true})

		# Disconnects from the server.
		#
		disconnect: ( ) ->
			@_connection.disconnect()
			
		# Sends a message to the remote.
		#
		# @param event [String] the event to send
		# @param args... [Any] any parameters you may want to pass
		#
		emit: ( event, args... ) ->
			args = [event].concat(args)
			@_connection.emit.apply(@_connection, args)

		# Sends a message to a peer, via the server.
		#
		# @param receiver [String] the id of the receiving peer
		# @param event [String] the event to send
		# @param args... [Any] any paramters you may want to pass
		#
		emitTo: ( id, event, args... ) ->
			args = ['emitTo', id, event].concat(args)
			@emit.apply(@, args)

		# Is called when an event is bound. This is used to trigger events when
		# a certain input is received from the remote.
		#
		# @param name [String] the event that's bound
		#
		_onEventBind: ( name ) =>
			if @_connection.listeners(name).length > 0
				return

			@_connection.on(name, ( args... ) =>
				args = [name].concat(args)
				@trigger.apply(@, args)
			)

		# Is called when an event is unbound. This is used to release a binding on
		# remote input.
		#
		# @param name [String] the event that's unbound
		#
		_onEventUnbind: ( name ) =>
			@_connection.removeAllListeners(name)

		# Is called when a connection is made. We emit our type to the server.
		# 
		_onConnect: ( ) =>
			console.log 'connected to server'
			@parent.id = @_connection.socket.sessionid
			$('.id').html(@parent.id)

