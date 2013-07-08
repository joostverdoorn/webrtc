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

			@on('event.bind', @_onEventBind)
			@on('event.unbind', @_onEventUnbind)

		# Disconnects from the client.
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