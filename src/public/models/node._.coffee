requirejs.config
	shim:
		'public/vendor/scripts/jquery.plugins': [ 'public/vendor/scripts/jquery' ]

define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'public/models/server'
	'public/models/peer'
	
	'underscore'

	'public/vendor/scripts/jquery'
	'public/vendor/scripts/jquery.plugins'
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

			@server.on('peer.connection.request', @_onPeerConnectionRequest)

			@bench()

			@initialize()

		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->

		connect: ( id ) ->
			peer = new Peer(@, id)
			peer.connect()
			@addPeer(peer)
		
		# Adds a peer to the peer list
		#
		# @param peer [Peer] the peer to add
		#
		addPeer: ( peer ) ->
			peer.on('peer.channel.opened', (peer ,data ) =>
				@trigger('peer.channel.opened', peer, data);
			)
			peer.on('peer.disconnected', (peer, data ) =>
				@trigger('peer.disconnected', peer );
			)
			@_peers.push(peer)

		# Removes a peer from the peer list
		#
		# @param peer [Peer] the peer to remove
		#
		removePeer: ( peer ) ->
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
			peer = new Peer(@, id)
			@addPeer(peer)

		bench: () =>
			startTime = performance.now()
			sha = "4C48nBiE586JGzhptoOV"
			for i in [0...256] by 1
				sha = CryptoJS.SHA3(sha).toString()
			output = value: sha
			endTime = performance.now()
			@benchmark.cpu = Math.round(endTime - startTime)
	


