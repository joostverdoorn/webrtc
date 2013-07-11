define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'public/models/remote.server'
	'public/models/remote.peer'
	
	'underscore'
	'jquery'

	'public/vendor/scripts/jquery.plugins'
	'public/vendor/scripts/crypto'

	], ( Mixable, EventBindings, Server, Peer, _, $ )->

	class Node extends Mixable

		@concern EventBindings

		id: null
		serverAddress: ':8080/'

		system: 
			osName:  $.os.name
			browserName:  $.browser.name
			browserVersion: $.browser.versionNumber
		benchmark:
			cpu: null		

		# Constructs a new app.
		#
		constructor: ( ) ->
			@isSuperNode = false

			# Unstructured entities
			@_peers = []
			@_unconnectedPeers = []

			# Structured entities
			@_parent = null

			@server = new Server(@, @serverAddress)

			@server.on('peer.connectionRequest', @_onPeerConnectionRequest)
			@server.on('peer.setRemoteDescription', @_onPeerSetRemoteDescription)
			@server.on('peer.addIceCandidate', @_onPeerAddIceCandidate)
			@server.on('connect', @_onServerConnect)

			@runBenchmark()



		# Attempts to connect to a peer.
		#
		# @param id [String] the id of the peer to connect to
		# @param connect [Boolean] wether to instantiate the connection
		#
		connect: ( id, connect = true ) ->
			peer = new Peer(@, id, connect)

			if duplicatePeer = @getPeer(peer.id, true)
				@_unconnectedPeers = _(@_unconnectedPeers).without(duplicatePeer)

			peer.on('connect', =>
				@_unconnectedPeers = _(@_unconnectedPeers).without(peer)
				@addPeer(peer)
			)

			@_unconnectedPeers.push(peer)
			return peer

		# Disconects a peer.
		#
		# @param id [String] the id of the peer to disconnect
		#
		disconnect: ( id ) ->
			@getPeer(id)?.disconnect()			

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
			if duplicatePeer = @getPeer(peer.id)
				@removePeer(duplicatePeer)

			peer.on('disconnected', ( peer ) =>
				@removePeer(peer)
			)

			@_peers.push(peer)
			@trigger('peer.added', peer)

		# Removes a peer from the peer list
		#
		# @param peer [Peer] the peer to remove
		#
		removePeer: ( peer ) ->
			peer.die()
			@_peers = _(@_peers).without(peer)
			@trigger('peer.removed', peer)

		# Returns a peer specified by an id
		#
		# @param id [String] the id of the requested peer
		# @param [Peer] the peer
		#
		getPeer: ( id, getUnconnected = false ) ->
			peers = @getPeers(null, getUnconnected)
			return _(peers).find( ( peer ) -> peer.id is id )

		# Returns an array of connected peers.
		#
		# @param role [Peer.Role] the role by which to filter the nodes
		# @return [Array<Peer>] an array containing all connected masters
		#
		getPeers: ( role = null, getUnconnected = false ) ->
			peers = @_peers
			if getUnconnected
				peers = @_unconnectedPeers.concat(peers)

			if role?
				return _(peers).filter( ( peer ) -> peer.role is role )
			else
				return peers

		# Sets a peer as the parent node of this node.
		#
		# @param peer [Peer] the peer to set as parent
		#
		setParent: ( peer, callback ) ->
			peer.query("requestParent", ( accepted ) =>
				if accepted
					@_parent?.role = Peer.Role.None
					peer.role = Peer.Role.Parent
					@_parent = peer
				callback(accepted)
			, @id)



		# Returns the parent peer of this node.
		#
		# @return [Peer] the parent peer
		#
		getParent: ( ) ->
			return @_parent

		# Adds a peer as child node.
		#
		# @param peer [Peer] the peer to add as child
		#
		addChild: ( peer ) ->
			if peer is @_parent
				@_parent = null

			peer.role = Peer.Role.Child

		# Removes a peer as child node. Does not automatically close 
		# the connection but will make it a normal peer.
		#
		# @param peer [Peer] the peer to remove as child
		#
		removeChild: ( peer ) ->
			peer.role = Peer.Role.None

		# Returns all current child nodes.
		#
		# @return [Array<Peer>] an array of all child nodes
		#
		getChildren: ( ) ->
			return @getPeers(Peer.Role.Child)

		# Adds a peer as sibling node.
		#
		# @param peer [Peer] the peer to add as sibling
		#
		addSibling: ( peer ) ->
			if peer is @_parent
				@_parent = null

			peer.role = Peer.Role.Sibling

		# Removes a peer as sibling node. Does not automatically close 
		# the connection but will make it a normal peer.
		#
		# @param peer [Peer] the peer to remove as sibling
		#
		removeSibling: ( peer ) ->
			peer.role = Peer.Role.None

		# Returns all current sibling nodes.
		#
		# @return [Array<Peer>] an array of all sibling nodes
		#
		getSiblings: ( ) ->
			return @getPeers(Peer.Role.Sibling)

		startSuperNode: () =>
			unless @isSuperNode
				@isSuperNode = true
				@server.emit("setSuperNode",@isSuperNode)
				@trigger("setSuperNode", @isSuperNode)


		stopSuperNode: () =>
			if @isSuperNode
				@isSuperNode = false
				@server.emit("setSuperNode",@isSuperNode)
				@trigger("setSuperNode", @isSuperNode)

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
				when 'isSuperNode' 
					return @isSuperNode
				when 'peers'
					return _(@getPeers()).map( ( peer ) -> peer.id )
				# accept at most 4 children ndoes
				when 'requestParent'
					if @getChildren().length < 4
						child  = @getPeer(args[0])
						if child?
							@addChild(child)
							return true
					return false



		# Runs a benchmark to get the available resources on this node.
		#
		runBenchmark: () =>
			startTime = performance.now()			
			sha = "4C48nBiE586JGzhptoOV"

			for i in [0...128]
				sha = CryptoJS.SHA3(sha).toString()

			endTime = performance.now()
			@benchmark.cpu = Math.round(endTime - startTime)

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
			@getPeer(id, true)?.setRemoteDescription(description)

		# Is called when a peer wants to add an ICE candidate
		#
		# @param id [String] the id string of the peer
		# @param data [Object] a plain object representation of an RTCIceCandidate
		#
		_onPeerAddIceCandidate: ( id, data ) =>
			candidate = new RTCIceCandidate(data)
			@getPeer(id, true)?.addIceCandidate(candidate)

		_onServerConnect: () =>
			@server.query("nodes", (nodes) =>
				if nodes.length is 1 and _(nodes).first().id is @id
					@startSuperNode()
				else 					
					superNodes = _(nodes).filter( (node) -> node.isSuperNode)
					@_chooseParent(superNodes)
					

			)

		_chooseParent: (superNodes) =>
			superNode = superNodes.pop()
			peer = @connect(superNode.id)
			peer.on("channel.opened", () =>
				@setParent(peer, (accepted) =>
					unless accepted
						peer.disconnect()
						if superNodes.length > 0
							@_chooseParent(superNodes)
				)
			)


					  
						
				



