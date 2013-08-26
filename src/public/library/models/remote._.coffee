define [
	'library/helpers/mixable'
	'library/helpers/mixin.eventbindings'

	'library/models/message'

	'underscore'

	], ( Mixable, EventBindings, Message, _ ) ->

	class Remote extends Mixable

		@concern EventBindings
		latency : Infinity

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
			@on('relay', @_onRelay)
			@on('log', -> console.log(arguments))

		# Disconnects the remote and removes all bindings.
		#
		die: ( ) ->
			if @isConnected()
				@emit("disconnect")
				@disconnect()
			@off()

		# Is called when a data channel message is received. Discards any
		# duplicate messages.
		#
		# @param message [String] the unparsed message
		#
		_onMessage: ( message ) =>
			if message.isStored(@_controller.messageStorage) or message.from is @_controller.id
				return

			message.storeHash(@_controller.messageStorage)

			if message.event is 'partial'
				@_assemble.apply(@, message.args)
				return

			if message.to is @_controller.id
				args = [message.event].concat(message.args).concat(message)
				@trigger.apply(@, args)
			else if message.to is '*'
				args = [message.event].concat(message.args).concat(message)
				@trigger.apply(@, args)
				@_controller.relay(message)
			else
				@_controller.relay(message)

		# Stores parts of a message and assembles the message when all
		# parts are received, in which case it triggers a message event
		# so the message is handled as usual.
		#
		# @param part [Object] the message part
		#
		_assemble: ( part ) =>
			if message = Message.assemble(part, @_controller.partialMessages)
				@trigger('message', message)

		# Disassembles a message and emits the pieces.
		#
		# @param message [Message] the message to disassemble
		# @param maxLength [Integer] the maximum size of the pieces
		#
		_disassemble: ( message, maxLength = 300 ) =>
			for part in message.disassemble(maxLength)
				@emit('partial', part)

		# Sends a predefined message to the remote, but first hashes the message
		# to make sure it's ignored when someone bounces it back to us.
		#
		# @param message [Message] the message to send
		#
		send: ( message ) ->
			if --message.ttl < 0 then return

			unless message.isStored(@_controller.messageStorage)
				message.storeHash(@_controller.messageStorage)

			message.route.push @_controller.id
			@_send(message)

		# Attempts to emit a message to the remote.
		#
		# @overload emit( event, args... )
		# 	 Convenient way to send a message to the peer.
		#	 @param event [String] the event to pass to the peer
		# 	 @param args... [Any] any other arguments to pass along
		#
		# @overload emit( params )
		# 	 More advanced way that allows for specifying ttl and route.
		#	 @param params [Object] an object containing params
		#	 @option params event [String] the event to pass to the peer
		# 	 @option params args [Array<Any>] any other arguments to pass along
		#	 @option params path [Array] the route the message should take
		# 	 @option params ttl [Integer] the number of hops the message may take
		#
		emit: ( ) ->
			params = {}

			if typeof arguments[0] is 'string'
				event = arguments[0]
				args  = Array::slice.call(arguments, 1)

			else if typeof arguments[0] is 'object'
				event 	= arguments[0].event
				args 	= arguments[0].args

				params.path = arguments[0].path
				params.ttl  = arguments[0].ttl

			message = new Message(@id, @_controller.id, @_controller.time(), event, args, params)
			@send(message)

		# Attempts to query the remote.
		#
		# @overload query( to, request, args..., callback )
		# 	 Convenient way to query a peer by id.
		# 	 @param request [String] the request string identifier
		# 	 @param args... [Any] any other arguments to be passed along with the query
		# 	 @param callback [Function] the function to call when a response has arrived
		#
		# @overload query( params )
		# 	 More advanced way that allows for specifying ttl and route.
		#	 @param params [Object] an object containing params
		#	 @option params request [String] the request string identifier
		# 	 @option params args [Array<Any>] any other arguments to be passed along with the quer
		# 	 @option params callback [Function] the function to call when a response has arrived
		#	 @option params path [Array] the route the message should take
		# 	 @option params ttl [Integer] the number of hops the message may take
		#
		query: ( ) ->
			if typeof arguments[0] is 'string'
				request  = arguments[0]
				args 	 = Array::slice.call(arguments, 1, arguments.length - 1)
				callback = arguments[arguments.length - 1]

			else if typeof arguments[0] is 'object'
				request  = arguments[0].request
				args 	 = arguments[0].args
				callback = arguments[0].callback

				path 	 = arguments[0].path
				ttl  	 = arguments[0].ttl

			# Setup callbacks and timeout.
			queryID = _.uniqueId('query')

			timer = setTimeout( ( ) =>
				callback(null)
			, @_controller.queryTimeout)

			fn = ( argms... ) =>
				callback.apply(@, argms)
				clearTimeout(timer)
			@once(queryID, fn)

			# Emit the message.
			params =
				event: 'query'
				args:  [request, queryID].concat(args)
				path:  path ? []
				ttl:   ttl  ? Infinity

			@emit(params)

		# Is called when a remote query is received. Will query the parent and emit
		# the results back.
		#
		# @param request [String] the request string identifier
		# @param queryID [String] the query identifier used to respond to the query
		# @param args... [Any] any other arguments to be passed along with the query
		#
		_onQuery: ( request, queryID, args..., message ) =>
			callback = ( argms... ) =>
				@_controller.emitTo
					to: message.from
					event: queryID
					args: argms
					path: _(message.route.reverse()).without(message.from)

			args = [request, callback].concat(args)
			@_controller.queries.trigger.apply(@_controller.queries, args)

		# Is called when we are requested by the remote to relay a message.
		#
		# @param messageString [String] a serialized version of the message to be relayed
		# @param msg [Message] the message containing the relay request
		#
		_onRelay: ( messageString, msg ) ->
			message = Message.deserialize(messageString)
			message.route = message.route.concat(msg.route)
			if message.to is @_controller.id
				@trigger('message', message)
			else @_controller.relay(message)

		# Pings the server. A callback function should be provided to do anything
		# with the ping.
		#
		# @param callback [Function] the callback to be called when a pong was received.
		#
		ping: ( callback ) =>
			time = Date.now()

			# First argument is the string 'pong'
			fn = ( pong, args... ) =>
				unless pong is 'pong'
					return

				@latency = Date.now() - time
				args = [@latency].concat(args)
				callback?.apply(@, args)

			@query('ping', fn)

		# Abstract function to be implemented by another class
		#
		# @param message [Message] the message to send
		#
		_send: ( message ) ->
			throw new Error("Not implemented")

		# Abstract function to be implemented by another class
		#
		# @param args [Any] any arguments to pass along to subclasses
		#
		initialize: ( args... ) ->
			throw new Error("Not implemented")

		# Abstract function to be implemented by another class to determine if there is a connection
		#
		# @return [Boolean] if there is a connection
		#
		isConnected: ( ) ->
			throw new Error("Not implemented")

		# Abstract function to be implemented by another class to kill a connection
		#
		disconnect: ( ) ->
			throw new Error("Not implemented")
