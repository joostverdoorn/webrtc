define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'underscore'
	], ( Mixable, EventBindings, _ ) ->

	class Remote extends Mixable

		@concern EventBindings

		# Constructs a remote.
		#
		# @param parent [Object] the parent object (Server or Node).
		# @param args... [Any] any arguments to pass along to subclasses
		#
		constructor: ( @parent, args... ) ->
			@initialize.apply(@, args)

			@on('ping', @_onPing)
			@on('pong', @_onPong)
			@on('query', @_onQuery)
			@on('emitTo', @_onEmitTo)

		# Queries the remote. Calls the callback function when a response is received.
		#
		# @param request [String] the request string identifier
		# @param callback [Function] the function to call when a response was received
		# @param args [Any] any other arguments to be passed along with the query
		#
		query: ( request, callback, args... ) ->
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
		_onQuery: ( request, queryID, args... ) =>
			args = [request].concat(args)
			result = @parent.query.apply(@parent, args)
			@emit(queryID, result)

		# Is called when the remote wants us to pass along a message to another peer. 
		# Will call emitTo on our parent to pass this message.
		#
		# @param id [String] the id of the peer to pass the message along to
		# @param args... [Any] any arguments to pass along to the peer
		#
		_onEmitTo: ( id, args... ) =>
			args = [id].concat(args)
			@parent.emitTo.apply(@parent, args)

		# Pings the server. A callback function should be provided to do anything
		# with the ping.
		#
		# @param callback [Function] the callback to be called when a pong was received.
		#
		ping: ( callback ) ->
			@_pingStart = Date.now()
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
			@latency = Date.now() - @_pingStart
			@_pingCallback?(@latency)
			@_pingStart = undefined




