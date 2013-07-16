define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'public/models/remote.server'
	'public/models/remote.peer'
	'public/models/message'
	'public/models/token'

	'public/models/collection'
	'public/models/vector'
	
	'underscore'

	'public/vendor/scripts/crypto'

	], ( Mixable, EventBindings, Server, Peer, Message, Collection, _ ) ->

	class Node extends Mixable

		@concern EventBindings

		id: null
		serverAddress: ':8080/'

		system: 
			osName:  'osName'
			browserName:  'browserName'
			browserVersion: 'browserVersion'
		benchmark:
			cpu: null

		broadcastTimeout = 4000 # Wait for return messages after a node broadcasts that it has a token
		tokenThreshhold = 0.5

		# Constructs a new app.
		#
		constructor: ( ) ->
			@isSuperNode = false

			# Unstructured entities
			@_peers = new Collection()
			@_tokens = new Collection()

			# Structured entities
			@_parent = null
			@token = null

			@server = new Server(@, @serverAddress)

			@server.on('peer.connectionRequest', @_onPeerConnectionRequest)
			@server.on('peer.setRemoteDescription', @_onPeerSetRemoteDescription)
			@server.on('peer.addIceCandidate', @_onPeerAddIceCandidate)
			@server.on('connect', @_onServerConnect)

			@coordinates = new Vector(Math.random(), Math.random())
			@coordinateDelta = 1

			@_peers.on('peer.setSuperNode', @_onPeerSetSuperNode)
			@_peers.on('token.add', @_tokenReceived)
			@_peers.on('token.hop', @_onTokenInfo)
			@_peers.on('token.info', @_onTokenInfo)
			@_peers.on('peer.requestTokenCandidate', @_onRequestTokenCandidate)
			@_peers.on('peer.receivedTokenCandidate', @_onReceivedTokenCandidate)

			setInterval(@update, 2500)

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
			peer.query('peer.requestParent', @id, ( accepted ) =>
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
				peer.emit('peer.addSibling', @id)

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
		setSuperNode: ( superNode = true ) =>
			@isSuperNode = superNode
			@server.emit('setSuperNode', @isSuperNode)
			@trigger('setSuperNode', @isSuperNode)
			@broadcast('peer.setSuperNode', @id, @isSuperNode)

		# Is called when a peer becomes a supernode
		#
		# @param _peer [Peer] The last routing peer
		# @param peerId [String] Id of the node that just became a supernode
		# @param superNode [boolean] SuperNode state
		#
		_onPeerSetSuperNode: (_peer, peerId, isSuperNode) =>
			if @isSuperNode
				peer = @getPeer(peerId)
				if peer?
					@addSibling(peer)
				else
					peer = @connect(peerId)
					peer.once('connect', =>
						@addSibling(peer)
					)

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
		
		# Relays a mesage to other nodes. If the intended receiver is not a direct 
		# neighbour, we route the message through other nodes in an attempt to reach 
		# the destination.
		#
		# @param message [Message] the message to relay.
		#
		relay: ( message ) ->
			if message.to is '*'
				peer.send(message) for peer in @getSiblings().concat(@getChildren()).concat(@getParent()) when peer?
			else if peer = @getChild(message.to) or peer = @getSibling(message.to)
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
				when 'ping'
					return @coordinates.serialize()
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

		###


		*** General functions end here ***


		###

		# Is called when a node enters a network
		#
		_onServerConnect: () =>
			@server.query("nodes", (nodes) =>
				if nodes.length is 1 and _(nodes).first().id is @id
					@token = new Token(@id, @id)
					@setSuperNode(true)
				else 					
					superNodes = _(nodes).filter( (node) -> node.isSuperNode)
					superNodes = _(superNodes).sortBy( (superNode) -> superNode.benchmark)
					_superNodes = superNodes.slice(0)
					@_chooseParent(superNodes)

					# Become a Supernode and become a Sibling ----- obsolete
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

		# Runs a benchmark to get the available resources on this node.
		#
		runBenchmark: () =>
			startTime = performance.now()			
			sha = "4C48nBiE586JGzhptoOV"

			for i in [0...128]
				sha = CryptoJS.SHA3(sha).toString()

			endTime = performance.now()
			@benchmark.cpu = Math.round(endTime - startTime)

		# Look up if node is having trouble 
		#
		# @return [Boolean] Return true if node has troubles 
		#
		hasDifficulties: () =>
			if @isSuperNode
				if @getChildren().length > 3
					return true
			return false

		# Generates a new token and gives it to a random child 
		#
		# @return [String] Returns id of the selected Child which will receive a token
		#
		generateToken: () =>
			if @hasDifficulties()
				token = new Token(null, @id)
				children = @getChildren()
				randomChild = children[_.random(0,children.length-1)]
				randomChild.emit("token.add",token.serialize())
				return randomChild.id
			
		# Is called when a node receives a token from another Node
		#	
		# @param peer [Peer] The last routing peer
		# @param tokenString [String] A serialized token
		#
		_tokenReceived: ( peer, tokenString ) =>
			@token = Token.deserialize(tokenString)
			@token.nodeId = @id
			@fromTokenToSuperNode()

		# Function is called when a node recieves a token
		#
		fromTokenToSuperNode: () =>
			@broadcast('token.hop', @token.serialize(), @coordinates.serialize(), true)
			@_tokenRestTimeout = setTimeout(( ) =>
				@calculateTokenMagnitude()
			, @broadcastTimeout)

		# Is called when a token hops. Sends a token information to the initiator
		#
		# @param peer [Peer] The last routing peer
		# @param tokenString [String] A serialised token
		# @param vectorString [String] Serialised coordinates of the holder of the token
		#
		_onTokenInfo: (peer, tokenString, vectorString, instantiate = true) =>
			token = Token.deserialize(tokenString)
			token.coordinates =  Vector.deserialize(vectorString)
			@addToken(token)
			if @token? and instantiate
				@emitTo(token.nodeId, 'token.info', @token.serialize(), @coordinates.serialize(), false)

		# Adds a token to the collection of foreign tokens
		#
		# @param [Token] A token to be added. This token can not be own token
		#
		addToken: (token) ->
			duplicateToken = _(@_tokens).find( (t) -> token.id is t.id)
			@_tokens.remove(duplicateToken)
			unless (@token? and @token.id is token.id)
				@_tokens.add(token)

		# Remove token from a collection of tokens
		#
		# @param [Token] A token to be removed.
		#
		removeToken: (token) ->
			@_tokens.remove(token)

		# Calculates the magnitude of own token and then broadcasts it to the rest
		#
		# #return [Float] Return Magnitude of the token
		#
		calculateTokenMagnitude: () =>
			tokenForce = Vector.makeZeroVector(@coordinates.length)
			for token in @_tokens
				direction = @coordinates.substract(token.coordinates)	# Difference between self and other Token
				direction = direction.calculateForce()					# Make Force smaller for bigger distances
				tokenForce = tokenForce.add(direction)					# Sum all token differences
			@token.position = @coordinates.substract(tokenForce)		# Calculate the new Token Position and save it in Token object
			tokenMagnitude = @coordinates.getDistance(@token.position)
			console.log tokenMagnitude

			if (tokenMagnitude > tokenThreshhold)
				# Ask other supernodes for their best child in neighboorhood of the tokenPosition
				@broadcast('peer.requestTokenCandidate', @token.serialize())
				setTimeout( () =>
					@pickNewTokenOwner()
				,@broadcastTimeout)
			else
				@setSuperNode(true)

			return tokenMagnitude
		
		# Is called when a token magnitude is calculated. A supernode selects his 
		# best child as candidate for the token
		#
		# @param peer [Peer] The last routing peer
		# @param tokenString [String] A serialised token
		#
		_onRequestTokenCandidate: (peer, tokenString) =>
			if(@isSuperNode)
				token = Token.deserialize(tokenString)
				bestCandidateDistance = null
				for child in @getChildren()
					distance = token.position.getDistance(child.coordinates)
					if !bestCandidateDistance? or distance < bestCandidateDistance
						bestCandidateDistance = distance
						bestCandidate = child
				if child?
					@emitTo(token.nodeId, "peer.receivedTokenCandidate", distance, child.id)
				
		# Is called when a node holding a token, receives other candidate nodes for the token
		#
		# @param peer [Peer] The last routing peer
		# @param distance [Float] Distance from the candidate to the token
		# @param nodeId [String] Node id of the candidate
		#
		_onReceivedTokenCandidate: (peer, distance, nodeId) =>
			unless @token.candidates?
				@token.candidates = new Array()
			candidate = new Object()
			candidate.distance = distance
			candidate.nodeId = nodeId
			@token.candidates.push(candidate)

		# Picks a new owner of the token. If the new owner is self, then it becomes a supernode
		#
		# @return[Node] Return a new owner of the token
		#
		pickNewTokenOwner: () =>
			bestCandidateDistance = null
			for candidate in @token.candidates
				if !bestCandidateDistance? or candidate.distance < bestCandidateDistance
					bestCandidateDistance = candidate.distance
					bestCandidate = candidate

			console.log "Best Candidate is " + bestCandidate.nodeId + " with distance " + bestCandidateDistance

			if bestCandidate.nodeId is @id
				@setSuperNode(true)
			else
				console.log @token
				@emitTo(bestCandidate.nodeId,"token.add", @token.serialize())
				@token = null
			return bestCandidate

		update: ( ) =>
			for peer in @getPeers()	
				direction = peer.coordinates.substract(@coordinates)		# Vector to peer
				distance = peer.coordinates.getDistance(@coordinates)		# Distance between node and peer
				error = distance - peer.latency								# Difference between distance and Latency

				direction = direction.unit()								# Make direction into unit vector
				displacement =  direction.scale(error * @coordinateDelta)	# Calculate displacement
				@coordinates = @coordinates.add( displacement )				# Calculate new coordinates
								
				@coordinateDelta = Math.max(0.05, @coordinateDelta - 0.025)
