#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
requirejs.config
	shim:
		'underscore':
			exports: '_'

		'socket.io':
			exports: 'io'

	# We want the following paths for
	# code-sharing reasons. Now it doesn't
	# matter from where we require a module.
	paths:
		'underscore': 'library/vendor/scripts/underscore'
		'adapter' : 'library/vendor/scripts/adapter'
		'socket.io': 'socket.io/socket.io'

define [
	'library/controller'

	'library/models/remote.server'
	'library/models/remote.peer'
	'library/models/message'

	'library/helpers/collection'
	'underscore'
	], ( Controller, Server, Peer, Message, Collection, _ ) ->

	# Constructs a new unstructured node.
	#
	class Node extends Controller

		id: null
		type: 'node'

		serverAddress: ':8080/'
		_timeDelta: 0

		# Constructs a new node. Calls initialize on any subclass.
		#
		# @param serverAddress [String] the uri address of the server
		#
		initialize: ( ) ->
			@server = new Server(@, @serverAddress)
			@server.on
				'connect': @_onServerConnect

			@_peers = new Collection()
			@_peers.on
				'disconnect': ( peer ) => @removePeer(peer)
				'timeout': ( peer ) => @removePeer(peer)
				'failed': ( peer ) => @removePeer(peer)

			@onQuery
				'ping': ( callback ) =>
					callback 'pong', @time()

				'type': ( callback ) =>
					callback @type

				'requestConnection': ( callback, id ) =>
					@connect(id, null, false)
					callback true

				'remoteDescription': ( callback, id, data ) =>
					if peer = @getPeer(id, null, true)
						peer.setRemoteDescription(data)
						peer.createAnswer(callback)
					else callback null

				'iceCandidates': ( callback, id, arr ) =>
					if peer = @getPeer(id, null, true)
						peer.addIceCandidates(arr)
						callback peer.localIceCandidates
					else callback null

				'info': ( callback ) =>
					info =
						id: @id
						type: @type
						peers: @getPeers().map( ( peer ) ->
							id: peer.id
							role: peer.role
						)

					callback info

		# Attempts to connect to a peer. Calls the callback function
		# with argument true when the connection was fully established,
		# and false when the connection timed out.
		#
		# @param id [String] the id of the peer to connect to
		# @param callback [Function] the callback to call
		# @param instantiate [Boolean] whether to instantiate the connection
		#
		connect: ( id, callback, instantiate = true ) ->
			if peer = @getPeer(id, null, true)
				if peer.isConnected()
					callback?(true)

				else peer.once
						'channel.opened': ( ) => callback?(true)
						'timeout': ( ) => callback?(false)
						'failed': ( ) => callback?(false)

				return peer

			peer = new Peer(@, id, instantiate)
			peer.once
				'channel.opened': ( ) => callback?(true)
				'timeout': ( ) => callback?(false)
				'failed': ( ) => callback?(false)

			@addPeer(peer)
			return peer

		# Disconnects a peer.
		#
		# @param id [String] the id of the peer to disconnect
		#
		disconnect: ( id ) ->
			@getPeer(id)?.disconnect()

		# Adds a peer to the peer list
		#
		# @param peer [Peer] the peer to add
		#
		addPeer: ( peer ) ->
			if not p = @getPeer(peer.id)
				@_peers.add(peer)
				@trigger('peer.added', peer)

		# Removes a peer from the peer list
		#
		# @param peer [Peer] the peer to remove
		#
		removePeer: ( peer ) ->
			peer.die()
			@_peers.remove(peer)
			@trigger('peer.removed', peer)

		# Returns a peer specified by an id
		#
		# @param id [String] the id of the requested peer
		# @return [Peer] the peer
		#
		getPeer: ( id, role = null, getUnconnected = false ) ->
			peers = @getPeers(role, getUnconnected)
			return _(peers).find( ( peer ) -> peer.id is id )

		# Returns an array of connected peers.
		#
		# @param role [Peer.Role] the role by which to filter the nodes
		# @return [Array<Peer>] an array containing all connected masters
		#
		getPeers: ( role = null, getUnconnected = false ) ->
			fn = ( peer ) ->
				return (not role? or role is peer.role) and
					(getUnconnected or peer.isConnected())

			return @_peers.filter(fn)

		# Public method to bind a callback on to a peer event.
		#
		# @overload onReceive( event, callback, context = @ )
		#	 Binds a single event.
		# 	 @param event [String] the string identifier of the event
		# 	 @param callback [Function] the function to call
		# 	 @param context [Object] the context on which to apply the callback
		#
		# @overload onReceive(bindings)
		#	 Binds multiple events.
		#	 @param bindings [Object] an object mapping events to callbacks
		#
		onReceive: ( ) ->
			if typeof arguments[0] is 'string'
				event = arguments[0]
				callback = arguments[1]
				context = arguments[2] || @

				@_peers.on(event, ( peer, args..., message ) =>
					args = args.concat(message)
					callback.apply(context, args)
				)

			else if typeof arguments[0] is 'object'
				bindings = arguments[0]

				for event, callback of bindings
					@onReceive(event, callback)

		# Attempts to query a peer by id.
		#
		# @overload queryTo( to, request, args..., callback )
		# 	 Convenient way to query a peer by id.
		# 	 @param to [String] the id of the peer to query
		# 	 @param request [String] the request string identifier
		# 	 @param args... [Any] any other arguments to be passed along with the query
		# 	 @param callback [Function] the function to call when a response has arrived
		#
		# @overload queryTo( params )
		# 	 More advanced way that allows for specifying ttl and route.
		#	 @param params [Object] an object containing params
		#	 @option params to [String] the id of the peer to pass the message to
		#	 @option params request [String] the request string identifier
		# 	 @option params args [Array<Any>] any other arguments to be passed along with the quer
		# 	 @option params callback [Function] the function to call when a response has arrived
		#	 @option params path [Array] the route the message should take
		# 	 @option params ttl [Integer] the number of hops the message may take
		#
		queryTo: ( ) ->
			if typeof arguments[0] is 'string'
				to 		 = arguments[0]
				request  = arguments[1]
				args 	 = Array::slice.call(arguments, 2, arguments.length - 1)
				callback = arguments[arguments.length - 1]
				retries  = 0

			else if typeof arguments[0] is 'object'
				to 		 = arguments[0].to
				request  = arguments[0].request
				args 	 = arguments[0].args ? []
				callback = arguments[0].callback

				path 	 = arguments[0].path
				ttl  	 = arguments[0].ttl
				retries  = arguments[0].retries ? 0

			# Setup callbacks and timeout.
			queryID = _.uniqueId('query')
			timer = setTimeout( ( ) =>
				@_peers.off(queryID)
				@server.off(queryID)

				unless retries < 1
					callback(null)
					return

				params =
					to: to
					request: request
					args: args
					callback: callback
					path: ['server'].concat(path ? [])
					ttĺ: ttl
					retries: ++retries ? 0

				@queryTo(params)

			, @queryTimeout)

			peerCallback = ( peer, argms... ) =>
				@server.off(queryID)
				callback.apply(@, argms)
				clearTimeout(timer)

			serverCallback = ( argms... ) =>
				@_peers.off(queryID)
				callback.apply(@, argms)
				clearTimeout(timer)

			@_peers.once(queryID, peerCallback)
			@server.once(queryID, serverCallback)

			# Emit the message.
			params =
				to:    to
				event: 'query'
				args:  [request, queryID].concat(args)
				path:  path ? []
				ttl:   ttl  ? Infinity

			@emitTo(params)

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

		# Relays a message to other nodes. If the intended receiver is not a direct
		# neighbor, we route the message through other nodes in an attempt to reach
		# the destination.
		#
		# @param message [Message] the message to relay.
		#
		relay: ( message ) ->
			if message.to is 'server'
				@server.send(message)

			else if message.to is '*'
				peer.send(message) for peer in @getPeers() when peer not in message.route

			else if peer = @getPeer(message.to)
				peer.send(message)

			else @server.send(message)

		# Is called when the server connects. Will ping the server and compute
		# the network time based on the server time and latency.
		# @private
		_onServerConnect: ( id ) =>
			@id = id
			@server.ping( ( latency, serverTime ) =>
				@_timeDelta = serverTime - (Date.now() - latency / 2)
			)

		# Is called when a peer requests a connection with this node. Will
		# accept this request by establishing a connection.
		#
		# @param id [String] the id of the peer
		# @private
		_onPeerConnectionRequest: ( id ) =>
			@connect(id, null, false)

		# Is called when a remote peer wants to set a remote description.
		#
		# @param id [String] the id string of the peer
		# @param data [Object] a plain object representation of an RTCSessionDescription
		# @private
		_onPeerSetRemoteDescription: ( id, data ) =>
			description = new RTCSessionDescription(data)
			@getPeer(id, null, true)?.setRemoteDescription(description)

		# Is called when a peer wants to add an ICE candidate
		#
		# @param id [String] the id string of the peer
		# @param data [Object] a plain object representation of an RTCIceCandidate
		#
		_onPeerAddIceCandidate: ( id, data ) =>
			candidate = new RTCIceCandidate(data)
			@getPeer(id, null, true)?.addIceCandidate(candidate)

		# Returns the network time.
		#
		# @return [Integer] the network time in milliseconds
		#
		time: ( ) ->
			return Date.now() + @_timeDelta
