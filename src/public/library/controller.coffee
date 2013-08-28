define [
	'library/helpers/mixable'
	'library/helpers/mixin.eventbindings'

	'library/models/message'

	'library/helpers/listener'
	'library/helpers/collection'

	], ( Mixable, EventBindings, Message, Listener ) ->

	class Controller extends Mixable

		@concern EventBindings

		id: null
		type: null

		queryTimeout: 2500

		constructor: ( args... ) ->
			@messageStorage = []
			@partialMessages = {}
			@queries = new Listener()

			@initialize?(args)

		# Attempts to emit to a peer by id.
		#
		# @overload emitTo( to, event, args... )
		# 	 Convenient way to send a message to a peer by id.
		# 	 @param to [String] the id of the peer to pass the message to
		#	 @param event [String] the event to pass to the peer
		# 	 @param args... [Any] any other arguments to pass along
		#
		# @overload emitTo( params )
		# 	 More advanced way that allows for specifying ttl and route.
		#	 @param params [Object] an object containing params
		#	 @option params to [String] the id of the peer to pass the message to
		#	 @option params event [String] the event to pass to the peer
		# 	 @option params args [Array<Any>] any other arguments to pass along
		#	 @option params path [Array] the route the message should take
		# 	 @option params ttl [Integer] the number of hops the message may take
		#
		emitTo: ( ) ->
			params = {}

			if typeof arguments[0] is 'string'
				to 	  = arguments[0]
				event = arguments[1]
				args  = Array::slice.call(arguments, 2)

			else if typeof arguments[0] is 'object'
				to 		= arguments[0].to
				event 	= arguments[0].event
				args 	= arguments[0].args ? []

				params.path = arguments[0].path
				params.ttl  = arguments[0].ttl

			message = new Message(to, @id, @time(), event, args, params)
			@relay(message)

		# Broadcasts a message to all peers in network.
		#
		# @param event [String] the event to broadcast
		# @param args... [Any] any other arguments to pass along
		#
		broadcast: ( event, args... ) ->
			@emitTo
				to: '*'
				event: event
				args: args

		# Binds a query.
		#
		# @overload on( name, callback, context = null )
		#	 Binds a single event.
		# 	 @param name [String] the event name to bind
		# 	 @param callback [Function] the callback to call
		# 	 @param context [Object] the context of the binding
		#
		# @overload on(bindings)
		#	 Binds multiple events.
		#	 @param bindings [Object] an object mapping event names to functions
		#
		onQuery: ( ) ->
			if typeof arguments[0] is 'string'
				name = arguments[0]
				callback = arguments[1]
				context = arguments[2] || null

				@queries.off(name)
				@queries.on(name, callback, context)

			else if typeof arguments[0] is 'object'
				bindings = arguments[0]

				for name, callback of bindings
					@onQuery(name, callback)

			return @