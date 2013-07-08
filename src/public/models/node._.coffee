requirejs.config
	shim:
		'public/vendor/scripts/jquery.plugins': [ 'public/vendor/scripts/jquery' ]
		'public/vendor/scripts/bootstrap.min': [ 'public/vendor/scripts/jquery' ]

define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'public/models/remote.server'
	'public/models/remote.peer'
	
	'underscore'

	'public/vendor/scripts/jquery'
	'public/vendor/scripts/jquery.plugins'
	'public/vendor/scripts/bootstrap.min'
	'public/vendor/scripts/crypto'

	], ( Mixable, EventBindings, Server, Peer, _ )->

	class Node extends Mixable

		@concern EventBindings

		id: null
		system: 
			osName:  $.os.name
			browserName:  $.browser.name
			browserVersion: $.browser.versionNumber
		benchmark:
			cpu: null
		serverAddress: ':8080/'

		# Constructs a new app.
		#
		constructor: ( ) ->
			@_peers = []

			@server = new Server(@, @serverAddress)

			@server.on('peer.connectionRequest', @_onPeerConnectionRequest)
			@server.on('peer.setRemoteDescription', @_onPeerSetRemoteDescription)
			@server.on('peer.addIceCandidate', @_onPeerAddIceCandidate)

			@bench()

			@initialize()

		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->

		# Attempts to connect to a peer.
		#
		# @param id [String] the id of the peer to connect to
		#
		connect: ( id ) ->
			peer = new Peer(@, id)
			@addPeer(peer)

		# Disconects a peer.
		#
		# @param id [String] the id of the peer to disconnect
		#
		disconnect: ( id ) ->
			peer = @getPeer(id)
			if peer?
				@removePeer(peer)

		# Tells the server to emit a message on to the specified peer.
		#
		# @param id [String] the id of the peer to pass the message to
		# @param event [String] the event to pass to the peer
		# @param args... [Any] any other arguments to pass along 
		#
		emitTo: ( id, event, args... ) ->
			args = [id, event].concat(args)
			@server.emitTo.apply(@server, args)
		
		# Adds a peer to the peer list
		#
		# @param peer [Peer] the peer to add
		#
		addPeer: ( peer ) ->
			peer.on('channel.opened', (peer ,data ) =>
				@trigger('peer.channel.opened', peer, data);
			)
			peer.on('disconnected', (peer, data ) =>
				@trigger('peer.disconnected', peer );
			)
			@_peers.push(peer)

		# Removes a peer from the peer list
		#
		# @param peer [Peer] the peer to remove
		#
		removePeer: ( peer ) ->
			peer.die()
			@_peers = _(@_peers).without(peer)

		# Returns a peer specified by an id
		#
		# @param id [String] the id of the requested peer
		# @param [Peer] the peer
		#
		getPeer: ( id ) ->
			return _(@_peers).find( ( peer ) -> peer.id is id )

		# Returns an array of connected peers.
		#
		# @param type [String] the type by which to filter the nodes
		# @return [Array<Peer>] an array containing all connected masters
		#
		getPeers: ( type = null ) ->
			if type?
				return _(@_peers).filter( ( peer ) -> peer.type is type )
			else
				return @_peers

		# Is called when a peer requests a connection with this node. Will
		# accept this request by establishing a connection.
		#
		# @param id [String] the id of the peer
		# @param type [String] the type of the peer
		#
		_onPeerConnectionRequest: ( id, type ) =>
			peer = new Peer(@, id, false)
			@addPeer(peer)

		# Is called when a remote peer wants to set a remote description.
		#
		# @param id [String] the id string of the peer
		# @param data [Object] a plain object representation of an RTCSessionDescription
		#
		_onPeerSetRemoteDescription: ( id, data ) =>
			description = new RTCSessionDescription(data)
			@getPeer(id)?.setRemoteDescription(description)

		# Is called when a peer wants to add an ICE candidate
		#
		# @param id [String] the id string of the peer
		# @param data [Object] a plain object representation of an RTCIceCandidate
		#
		_onPeerAddIceCandidate: ( id, data ) =>
			candidate = new RTCIceCandidate(data)
			@getPeer(id)?.addIceCandidate(candidate)

		# Responds to a request
		#
		# @param request [String] the string identifier of the request
		# @param args... [Any] any arguments that may be accompanied with the request
		# @return [Object] a response to the query
		#
		query: ( request, args... ) ->
			switch request
				when 'system' 
					return @system
				when 'benchmark'
					return @benchmark
				when 'type'
					return @type
				when 'peers'
					return _(@getPeers()).map( ( peer ) -> peer.id )

		bench: () =>
			startTime = performance.now()
			sha = "4C48nBiE586JGzhptoOV"
			for i in [0...256] by 1
				sha = CryptoJS.SHA3(sha).toString()
			output = value: sha
			endTime = performance.now()
			@benchmark.cpu = Math.round(endTime - startTime)

