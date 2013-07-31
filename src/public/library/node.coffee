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
	'public/library/helpers/mixable'
	'public/library/helpers/mixin.eventbindings'

	'public/library/models/remote.server'
	'public/library/models/remote.peer'
	'public/library/models/message'

	'public/library/models/collection'
	
	'underscore'

	], ( Mixable, EventBindings, Server, Peer, Message, Collection, _ ) ->

	# Constructs a new unstructured node.
	#
	class Node extends Mixable

		@concern EventBindings

		id: null
		serverAddress: ':8080/'

		constructor: ( ) ->

			@_peers = new Collection()

			@server = new Server(@, @serverAddress)


			@server.on('peer.connectionRequest', @_onPeerConnectionRequest)
			@server.on('peer.setRemoteDescription', @_onPeerSetRemoteDescription)
			@server.on('peer.addIceCandidate', @_onPeerAddIceCandidate)


			@_peers.on('disconnect', @_onPeerDisconnect)

			@initialize?.apply(@)

			###
			# This will help us log errors. It makes 
			# console.log print to both console and server.
			# Logs can be retrieved at /log
			console.rLog = console.log
			console.log = ( args... ) ->
				console.rLog.apply(@, args)
				App.node.server.emit('debug', args)
			###
			
		# Attempts to connect to a peer.
		#
		# @param id [String] the id of the peer to connect to
		# @param instantiate [Boolean] whether to instantiate the connection
		#
		connect: ( id, instantiate = true ) ->
			peer = new Peer(@, id, instantiate)
			@addPeer(peer)
			return peer

		# Removes all timers
		#
		removeIntervals: ( ) ->
			for timer in @timers
				clearTimeout(timer)
			
		# Disconnects a peer.
		#
		# @param id [String] the id of the peer to disconnect
		#
		disconnect: ( id ) ->
			@getPeer(id)?.disconnect()

		# Is called when a peers disconnects.
		#
		# @param peer [Peer] the peer that disconnects
		#
		_onPeerDisconnect: ( peer ) =>
			@removePeer(peer)

		# Adds a peer to the peer list
		#
		# @param peer [Peer] the peer to add
		#
		addPeer: ( peer ) ->
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

		# Public method to bind a callback on to a peer event
		#
		# @param event [String] the string identifier of the event
		# @param callback [Function] the function to call
		# @param context [Object] the context on which to apply the callback
		#
		onReceive: ( event, callback, context = @ ) ->
			@_peers.on(event, ( peer, args... ) =>
				callback.apply(context, args)
			)

		# Is called when a peer requests a connection with this node. Will
		# accept this request by establishing a connection.
		#
		# @param id [String] the id of the peer
		# @param type [String] the type of the peer
		#
		_onPeerConnectionRequest: ( id, type ) =>
			@connect(id, false)

		# Is called when a remote peer wants to set a remote description.
		#
		# @param id [String] the id string of the peer
		# @param data [Object] a plain object representation of an RTCSessionDescription
		#
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

		# Attempts to emit to a peer by id. Unreliable.
		#
		# @param to [String] the id of the peer to pass the message to
		# @param event [String] the event to pass to the peer
		# @param args... [Any] any other arguments to pass along 
		#
		emitTo: ( to, event, args... ) ->
			message = new Message(to, @id, event, args)
			@relay(message)

		# Attempts to query a peer by id. Unreliable.
		#
		# @param to [String] the id of the peer to query
		# @param request [String] the request string identifier
		# @param callback [Function] the function to call when a response has arrived
		# @param args... [Any] any other arguments to be passed along with the query
		#
		queryTo: ( to, request, callback, args... ) ->
			queryID = _.uniqueId('query')
			args = [to, 'query', request, queryID].concat(args)
			@_peers.once(queryID, callback)
			@emitTo.apply(@, args)
		
		# Broadcasts a message to all peers in network.
		#
		# @param event [String] the event to broadcast
		# @param args... [Any] any other arguments to pass along
		#
		broadcast: ( event, args... ) ->
			message = new Message('*', @id, event, args)
			@relay(message)
		
		# Relays a message to other nodes. If the intended receiver is not a direct 
		# neighbor, we route the message through other nodes in an attempt to reach 
		# the destination.
		#
		# @param message [Message] the message to relay.
		#
		relay: ( message ) ->
			peer.send(message)

		# A Query function is implemented in a structured version of Node
		#
		query: ( request, args..., callback ) ->
			switch request
				when 'ping'
					callback 'pong'
				else
					callback undefined