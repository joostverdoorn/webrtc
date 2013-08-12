define [
	'public/library/helpers/mixable'
	'public/library/helpers/mixin.eventbindings'

	'public/library/models/message'

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
			if message.isStored(@_controller.messageStorage)
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
		# @param messageID [Integer] the ID (hash) of the message
		# @param totalParts [Integer] the total number of parts the message consists of
		# @param partNumber [Integer] the number of this part
		# @param partData [String] the data of this part
		#
		_assemble: ( messageID, totalParts, partNumber, partData ) =>
			# Store the part.
			unless @_controller.partialMessages[messageID]?
				@_controller.partialMessages[messageID] = []

			@_controller.partialMessages[messageID][partNumber] = partData

			# Try to assemble the message.
			if @_controller.partialMessages[messageID].length < totalParts
				return

			messageString = ""
			for data in @_controller.partialMessages[messageID]
				unless data? then return
				messageString += data

			delete @_controller.partialMessages[messageID]
			@trigger('message', messageString)

		# Disassembles a message and emits the pieces.
		#
		# @param message [Message] the message to disassemble
		# @param maxSize [Integer] the maximum size of the pieces
		#
		_disassemble: ( message, maxSize = 400 ) =>
			messageString = message.serialize()
			length = messageString.length

			messageID = message.hash()
			totalParts = Math.ceil(length / maxSize)

			for partNumber in [0...totalParts]
				partData = messageString.substr(maxSize * partNumber, maxSize)
				@emit('partial', messageID, totalParts, partNumber, partData)

		# Compiles and sends a message to the remote.
		#
		# @param event [String] the event to send
		# @param args... [Any] any parameters you may want to pass
		#
		emit: ( event, args... ) ->
			message = new Message(@id, @_controller.id, event, args, @_controller.time())
			@send(message)

		# Tells the remote to forward a message to a peer specified by to.
		#
		# @param to [String] the id of the receiving peer
		# @param event [String] the event to send
		# @param args... [Any] any paramters you may want to pass
		#
		emitTo: ( to, event, args..., ttl ) ->
			message = new Message(to, @_controller.id, event, args, @_controller.time(), ttl)
			@send(message)

		# Sends a predefined message to the remote, but first hashes the message
		# to make sure it's ignored when someone bounces it back to us.
		#
		# @param message [Message] the message to send
		#
		send: ( message ) ->
			if --message.ttl <= 0 then return

			unless message.isStored(@_controller.messageStorage)
				message.storeHash(@_controller.messageStorage)

			@_send(message)

		# Queries the remote. Calls the callback function when a response is received, or
		# when the query has timed out, in which case the first argument passed to the
		# callback is null.
		#
		# @param request [String] the request string identifier
		# @param callback [Function] the function to call when a response was received
		# @param args [Any] any other arguments to be passed along with the query
		#
		query: ( request, args..., callback ) ->
			queryID = _.uniqueId('query')

			timer = setTimeout( ( ) =>
				@off(queryID)
				callback(null)
			, @_controller.queryTimeout)

			fn = ( argms... ) =>
				callback.apply(@, argms)
				clearTimeout(timer)

			@once(queryID, fn)

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
			callback = ( argms... ) =>
				argms = [message.from, queryID].concat(argms, Infinity)
				@emitTo.apply(@, argms)

			args = [request, callback].concat(args)
			@_controller.queries.trigger.apply(@_controller.queries, args)

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
