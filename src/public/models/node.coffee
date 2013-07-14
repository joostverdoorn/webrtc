define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'public/models/remote.server'
	'public/models/remote.peer'
	'public/models/message'

	'public/models/collection'
	
	'underscore'
	'jquery'
	'jquery.plugins'

	'public/vendor/scripts/crypto'

	], ( Mixable, EventBindings, Server, Peer, Message, Collection, _, $ )->

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
			@_peers = new Collection()

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
		# @param instatiate [Boolean] wether to instantiate the connection
		#
		connect: ( id, instatiate = true ) ->
			peer = new Peer(@, id, instatiate)
			@addPeer(peer)
			return peer

		# Disconects a peer.
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
			peer.on('disconnect', ( ) => @removePeer(peer))
			peer.on('peer.addSibling', ( ) => @addSibling(peer, false))

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

		# Sets a peer as the parent node of this node.
		#
		# @param peer [Peer] the peer to set as parent
		# @param callback [function] is called with a parameter if a node is accepted or not
		#
		setParent: ( peer, callback ) ->
			peer.query("peer.requestParent", @id, ( accepted ) =>
				if accepted
					@_parent?.role = Peer.Role.None
					peer.role = Peer.Role.Parent
					@_parent = peer
				callback(accepted)
			)

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

		# Returns a child specified by an id
		#
		# @param id [String] the id of the requested child
		# @return [Peer] the child
		#
		getChild: ( id ) ->
			return @getPeer(id, Peer.Role.Child)

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
		addSibling: ( peer, instantiate = true ) ->
			if peer is @_parent
				@_parent = null

			peer.role = Peer.Role.Sibling

			if instantiate
				peer.emit("peer.addSibling", @id)

		# Removes a peer as sibling node. Does not automatically close 
		# the connection but will make it a normal peer.
		#
		# @param peer [Peer] the peer to remove as sibling
		#
		removeSibling: ( peer ) ->
			peer.role = Peer.Role.None

		# Returns a sibling specified by an id
		#
		# @param id [String] the id of the requested sibling
		# @return [Peer] the sibling
		#
		getSibling: ( id ) ->
			return @getPeer(id, Peer.Role.Sibling)

		# Returns all current sibling nodes.
		#
		# @return [Array<Peer>] an array of all sibling nodes
		#
		getSiblings: ( ) ->
			return @getPeers(Peer.Role.Sibling)

		# Change a SuperNode state of a node
		#
		# @param superNode [boolean] SuperNode state
		#
		setSuperNode: ( superNode ) =>
			@isSuperNode = superNode
			@server.emit("setSuperNode",@isSuperNode)
			@trigger("setSuperNode", @isSuperNode)

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
		
		# Relays a mesage to other nodes. If the intended receiver is not a direct 
		# neighbour, we route the message through other nodes in an attempt to reach 
		# the destination.
		#
		# @param message [Message] the message to relay.
		#
		relay: ( message ) ->
			if peer = @getChild(message.to) or peer = @getSibling(message.to)
				peer.send(message)
			else if parent = @getParent()
				parent.send(message)
			else if @isSuperNode
				sibling.send(message) for sibling in @getSiblings() when sibling.id isnt message.from
			else
				@server.send(message)

		# Responds to a request
		#
		# @param request [String] the string identifier of the request
		# @param args... [Any] any arguments that may be accompanied with the request
		# @param from [Peer] the peer we received the query from
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
				when 'peer.requestParent'
					if @getChildren().length < 4
						child = @getPeer(args[0])
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

		# Is called when a node enters a network
		#
		_onServerConnect: () =>
			@server.query("nodes", (nodes) =>
				if nodes.length is 1 and _(nodes).first().id is @id
					@setSuperNode(true)
				else 					
					superNodes = _(nodes).filter( (node) -> node.isSuperNode)
					superNodes = _(superNodes).sortBy( (superNode) -> superNode.benchmark)
					_superNodes = superNodes.slice(0)
					@_chooseParent(superNodes)

					# Become a Supernode and become a Sibling
					@on("hasParent", (hasParent) =>
						for superNode in _superNodes
							unless hasParent
								@setSuperNode(true)			
								peer = @getPeer(superNode.id)
								@addSibling(peer)
					)
			)

		# Is called until a node connects to a Supernode
		#
		# @param superNodes [[Node]] an array of available superNodes
		#
		_chooseParent: ( superNodes ) =>
			if superNodes.length > 0
				superNode = superNodes.pop()
				peer = @connect(superNode.id)
				peer.on("channel.opened", () =>
					@setParent(peer, (accepted) =>
						if accepted
							@trigger("hasParent", true)
						else
							@_chooseParent(superNodes)
					)
				)
			else
				@trigger("hasParent", false)

