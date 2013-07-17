define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'public/models/message'

	'underscore'
	], ( Mixable, EventBindings, Message, _ ) ->

	class Remote extends Mixable

		@concern EventBindings

		@hashes = []

		# Constructs a remote.
		#
		# @param parent [Object] the parent object (Server or Node).
		# @param args... [Any] any arguments to pass along to subclasses
		#
		constructor: ( @_controller, args... ) ->
			@initialize.apply(@, args)

			@on('message', @_onMessage)
			@on('ping', @_onPing)
			@on('query', @_onQuery)
			@on('emitTo', @_onEmitTo)			
			@on('log', ( args... ) => console.log(args))			

		# Disconnects the remote and removes all bindings.
		#
		die: ( ) ->
			if @isConnected()
				@disconnect()

			@off()

		# Is called when a data channel message is received. Discards any 
		# duplicate messages.
		#
		# @param message [String] the unparsed message
		#
		_onMessage: ( messageString ) =>
			message = Message.deserialize(messageString)
			
			hash = message.hash()
			if hash in Remote.hashes
				return

			Remote.hashes.push(hash)
			if Remote.hashes.length > 1000
				Remote.hashes.splice(0, 200)

			if message.to is @_controller.id
				args = [message.event].concat(message.args).concat(message)
				@trigger.apply(@, args)
			else if message.to is '*'
				args = [message.event].concat(message.args).concat(message)
				@trigger.apply(@, args)
				@_controller.relay(message)
			else 
				@_controller.relay(message)

		# Compiles and sends a message to the remote.
		#
		# @param event [String] the event to send
		# @param args... [Any] any parameters you may want to pass
		#
		emit: ( event, args... ) ->
			message = new Message(@id, @_controller.id, event, args)
			@send(message)

		# Sends a message to a peer, via the server.
		#
		# @param to [String] the id of the receiving peer
		# @param event [String] the event to send
		# @param args... [Any] any paramters you may want to pass
		#
		emitTo: ( to, event, args... ) ->
			message = new Message(to, @_controller.id, event, args)
			@send(message)

		# Sends a predefined message to the remote, but first hashes the message 
		# to make sure it's ignored when someone bounces it back to us.
		#
		# @param message [Message] the message to send
		#
		send: ( message ) ->
			hash = message.hash()
			Remote.hashes.push(hash)
			if Remote.hashes.length > 1000
				Remote.hashes.splice(0, 200)
			
			@_send(message)

		# Queries the remote. Calls the callback function when a response is received.
		#
		# @param request [String] the request string identifier
		# @param callback [Function] the function to call when a response was received
		# @param args [Any] any other arguments to be passed along with the query
		#
		query: ( request, args..., callback ) ->
			queryID = _.uniqueId('query')
			@once(queryID, callback)

			args = ['query', request, queryID].concat(args)
			@emit.apply(@, args)

		# Is called when a remote query is received. Will query the parent and emit
		# the results back.
		#
		# @param request [String] the request string identifier
		# @param queryID [String] the query identifier used to respond to the query
		# @param args... [Any] any other arguments to be passed along with the query
		#
		_onQuery: ( request, queryID, args..., message ) =>
			args = [request].concat(args).concat(@)
			result = @_controller.query.apply(@_controller, args)
			@emitTo(message.from, queryID, result)

		# Pings the server. A callback function should be provided to do anything
		# with the ping.
		#
		# @param callback [Function] the callback to be called when a pong was received.
		#
		ping: ( callback ) =>
			time = performance.now()

			fn = ( args... ) =>
				@latency = performance.now() - time
				args = [@latency].concat(args)
				callback.apply(@, args)

			@query('ping', fn)
