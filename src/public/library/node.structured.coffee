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

	'public/library/node'
	'public/library/models/remote.server'
	'public/library/models/remote.peer'
	'public/library/models/message'
	'public/library/models/token'

	'public/library/models/collection'
	'public/library/models/vector'
	
	'underscore'

	], ( Mixable, EventBindings, Node, Server, Peer, Message, Token, Collection, Vector, _ ) ->

	# Constructs a new structured node.
	#
	class Node.Structured extends Node

		type: 'node.structured'

		broadcastTimeout = 4000 # Wait for return messages after a node broadcasts that it has a token
		tokenThreshhold = 1

		superNodeSwitchThreshhold = 0.6 # Scaler: from 0 to 1. More is easier switching
		kickstartPeers = 3

		initialize: () ->

			@server.on('connect', @_enterNetwork)
			@_parent = null
			@isSuperNode = false

			@_tokens = new Collection()
			@token = null

			@timers = []

			@coordinates = new Vector(Math.random(), Math.random(), Math.random())
			@coordinateDelta = 1
			
			@_peers.on('disconnect', @_onPeerDisconnect)
			@_peers.on('peer.addSibling', ( peer ) => @addSibling(peer, false))
			@_peers.on('peer.setSuperNode', @_onPeerSetSuperNode)
			@_peers.on('peer.parentCandidate', @_onPeerParentCandidate)
			@_peers.on('peer.abandonParent', ( peer ) => @removeChild(peer))

			@_peers.on('token.add', @_onTokenReceived)
			@_peers.on('token.hop', @_onTokenInfo)
			@_peers.on('token.info', @_onTokenInfo)
			@_peers.on('token.requestCandidate', @_onTokenRequestCandidate)
			@_peers.on('token.candidate', @_onTokenCandidate)

			@timers.push(setInterval(@_lookForBetterSupernode, 15000))
			@staySuperNodeTimeout = null

			@timers.push(setInterval(@_updateCoordinates, 7500))

		# Change a SuperNode state of a node
		#
		# @param superNode [boolean] SuperNode state
		#
		setSuperNode: ( superNode = true ) =>
			if superNode is not @isSuperNode
				if not superNode and @getSiblings().length is 0
					return
				@server.emit('setSuperNode', superNode)
				@trigger('setSuperNode', superNode) # App is listening
				@broadcast('peer.setSuperNode', @id, superNode)
				@isSuperNode = superNode
				if superNode
					@_triggerStaySuperNodeTimeout()
				else
					for sibling in @getSiblings()
						@removeSibling(sibling)
					@_pickParent()		

		# Sets a peer as the parent node of this node.
		#
		# @param peer [Peer] the peer to set as parent
		# @param callback [function] is called with a parameter if a node is accepted or not
		#
		setParent: ( peer, callback ) ->
			peer.query('peer.requestParent', @id, ( accepted ) =>
				if accepted
					@_parent?.emit('peer.abandonParent')
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
			if @getChildren().length > 4
				_(@generateToken).defer()

		# Removes a peer as child node. Does not automatically close 
		# the connection but will make it a normal peer.
		#
		# @param peer [Peer] the peer to remove as child
		#
		removeChild: ( peer ) ->
			peer.role = Peer.Role.None
			@_triggerStaySuperNodeTimeout()

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

		# Responds to a request
		#
		# @param request [String] the string identifier of the request
		# @param args... [Any] any arguments that may be accompanied with the request
		# @param callback [Function] the callback to call with the response
		#
		query: ( request, args..., callback ) ->
			switch request
				when 'ping'
					callback 'pong', @coordinates.serialize()
				when 'isSuperNode'
					callback @isSuperNode
				when 'peer.requestParent'
					if @isSuperNode and child = @getPeer(args[0])
						@addChild(child)
						callback true
					else
						callback false
				when 'info'
					info =
						id: @id
						type: @type
						coordinates: @coordinates
						isSuperNode: @isSuperNode
						peers: @getPeers().map( ( peer ) ->
							id: peer.id
							role: peer.role
						)

					callback info
				else
					super

		# Relays a message to other nodes. If the intended receiver is not a direct 
		# neighbor, we route the message through other nodes in an attempt to reach 
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

		# Applies Vivaldi algorithm. Calculates the coordinates of a node
		#
		_updateCoordinates: ( ) =>
			for peer in @getPeers()	
				direction = peer.coordinates.substract(@coordinates)		# Vector to peer
				distance = peer.coordinates.getDistance(@coordinates)		# Distance between node and peer
				error = distance - peer.latency								# Difference between distance and Latency

				direction = direction.unit()								# Make direction into unit vector
				displacement =  direction.scale(error * @coordinateDelta)	# Calculate displacement
				@coordinates = @coordinates.add( displacement )				# Calculate new coordinates
								
				@coordinateDelta = Math.max(0.05, @coordinateDelta - 0.025)


		# Is called when a node enters a network. This will either
		# make the current node a supernode, when no other supernodes
		# are found, or it connect to a bunch of other supernodes
		# and pick the one with the lowest latency is parent.
		#
		_enterNetwork: ( ) =>
			@server.query('nodes', 'node.structured', ( nodes ) =>
				superNodes = _(nodes).filter( ( node ) => node.isSuperNode )

				# If no supernodes present, become a supernode
				if superNodes.length is 0
					@token = new Token(@id, @id)
					@setSuperNode(true)
					@trigger('joined')

				# Else connect to a bunch of random supernodes
				else
					candidates = superNodes.slice(0)
					n = Math.min(kickstartPeers, superNodes.length)
					while candidates.length > kickstartPeers
						i = Math.floor(candidates.length * Math.random)
						candidates.splice(i, 1)

					pingCount = 0
					peers = []

					for candidate in candidates
						peer = @connect(candidate.id)
						peers.push(peer)
						
						# Ping all the connected supernodes and set
						# the one with the largest ping as parent.
						# We keep the connection to the others open
						# aid in finding our coordinates.
						( ( peer ) =>
							peer.on('channel.opened', =>
								peer.ping( ( latency ) => 
									pingCount++
									if pingCount is candidates.length
										@_pickParent( null, ( joined ) =>
											if joined
												@trigger('joined')
										)
								)
							)
						) ( peer )
			)

		# Triggers a timeout for _superNodeTimeout  method. If a timeout is not cleared from somewhere else
		# _superNodeTimeout method will be called
		#
		_triggerStaySuperNodeTimeout: () =>
			if @getChildren().length is 0
				clearTimeout(@staySuperNodeTimeout)
				@staySuperNodeTimeout = setTimeout( ( ) =>
					@_superNodeTimeout()
				, 20000)
				@timers.push(@staySuperNodeTimeout)

		# Is called through timeout. If a supernode has not children, it stops being a supernode
		#
		_superNodeTimeout: () =>
			if @getChildren().length is 0 and @isSuperNode
				@setSuperNode(false)
				clearTimeout(@staySuperNodeTimeout)

		# Is called when a peer becomes a supernode
		#
		# @param _peer [Peer] The last routing peer
		# @param peerId [String] Id of the node that just became a supernode
		# @param superNode [boolean] SuperNode state
		#
		_onPeerSetSuperNode: (_peer, peerId, isSuperNode) =>
			peer = @getPeer(peerId)
			if peer?
				peer.isSuperNode = isSuperNode

				if @isSuperNode
					if isSuperNode
						@addSibling(peer)
					else
						@removeSibling(peer)
			else if @isSuperNode
				peer = @connect(peerId)
				peer.once('channel.opened', =>
					@addSibling(peer)
				)
			else if isSuperNode and _(@getPeers()).filter( ( peer ) -> peer.isSuperNode).length < kickstartPeers
				@connect(peerId)

		# Recursive function that attempts to pick a parent from all
		# connected supernodes. If a parent request is refused,
		# this function calls itself with all candidates that have
		# not yet refused a parent request. 
		#
		_pickParent: ( candidates = null, callback ) =>
			unless candidates?
				candidates = _(@getPeers()).filter( ( p ) -> p.isSuperNode )
			if candidates.length > 0
				candidates = _(candidates).sortBy( 'latency' )
				candidate = candidates.shift()
				@setParent(candidate, ( accepted ) =>
					if accepted
						console.log("parent request to #{candidate.id} accepted")
						callback?(true)
					else
						console.log("parent request to #{candidate.id} denied")
						@_pickParent(candidates, callback)
				)
			else
				callback?(false)
				@_enterNetwork()

		# Is called when a peers disconnects. If that peer was 
		# our parent, we pick a new parent.
		#
		# @param peer [Peer] the peer that disconnects
		#
		_onPeerDisconnect: ( peer ) =>
			@_triggerStaySuperNodeTimeout()
			if peer is @getParent()
				candidates = _(@getPeers()).filter( ( p ) -> p.isSuperNode )
				@_pickParent(candidates)

		# Generates a new token and gives it to a random child 
		#
		# @return [String] Returns id of the selected Child which will receive a token
		#
		generateToken: () =>
			token = new Token(null, @id)
			children = @getChildren()
			randomChild = children[_.random(0,children.length-1)]
			randomChild.emit('token.add',token.serialize())
			console.log  randomChild.id +  ' received a token'

		# Adds a token to the collection of foreign tokens
		#
		# @param [Token] A token to be added. This token can not be own token
		#
		addToken: ( token ) ->
			duplicateToken = _(@_tokens).find( (t) -> token.id is t.id)
			@_tokens.remove(duplicateToken)
			unless (@token? and @token.id is token.id)
				@_tokens.add(token)

		# Remove token from a collection of tokens
		#
		# @param [Token] A token to be removed.
		#
		removeToken: ( token ) ->
			oldToken = _(@_tokens).find( ( t ) -> token.id is t.id)
			@_tokens.remove(oldToken)

		# Calculates the magnitude of own token and then broadcasts it to the rest
		#
		# #return [Float] Return Magnitude of the token
		#
		_calculateTokenMagnitude: ( ) ->
			tokenForce = Vector.createZeroVector(@coordinates.length)
			for token in @_tokens
				direction = @coordinates.substract(token.coordinates)	# Difference between self and other Token
				res = new Vector()										# Make Force smaller for bigger distances
				for i in [0...direction.length]
					res.push( 1 / direction[i])
				direction = res
				tokenForce = tokenForce.add(direction)					# Sum all token differences
			@token.position = @coordinates.substract(tokenForce)		# Calculate the new Token Position and save it in Token object
			tokenMagnitude = @coordinates.getDistance(@token.position)

			if (tokenMagnitude > tokenThreshhold)
				# Ask other supernodes for their best child in neighborhood of the tokenPosition
				@broadcast('token.requestCandidate', @token.serialize())
				setTimeout( ( ) =>
					@_pickNewTokenOwner()
				, @broadcastTimeout)
				@timers.push(@broadcastTimeout)
			else
				@setSuperNode(true)

			return tokenMagnitude

		# Is called when a node receives a token from another Node
		#	
		# @param peer [Peer] The last routing peer
		# @param tokenString [String] A serialized token
		#
		_onTokenReceived: ( peer, tokenString ) =>
			@token = Token.deserialize(tokenString)
			@removeToken(@token)
			@token.nodeId = @id

			@broadcast('token.hop', @token.serialize(), @coordinates.serialize(), true)
			@_tokenRestTimeout = setTimeout(( ) =>
				@_calculateTokenMagnitude()
			, @broadcastTimeout)
			@timers.push(@_tokenRestTimeout)

			# Is called when a token hops. Sends a token information to the initiator
		#
		# @param peer [Peer] The last routing peer
		# @param tokenString [String] A serialized token
		# @param vectorString [String] Serialized coordinates of the holder of the token
		#
		_onTokenInfo: ( peer, tokenString, vectorString, instantiate = true ) =>
			token = Token.deserialize(tokenString)
			console.log "Received info about token ", token
			token.coordinates = Vector.deserialize(vectorString)
			@addToken(token)
			if @token? and instantiate
				@emitTo(token.nodeId, 'token.info', @token.serialize(), @coordinates.serialize(), false)

		# Is called when a token magnitude is calculated. A supernode selects his 
		# best child as candidate for the token
		#
		# @param peer [Peer] The last routing peer
		# @param tokenString [String] A serialized token
		#
		_onTokenRequestCandidate: ( peer, tokenString ) =>
			if @isSuperNode
				token = Token.deserialize(tokenString)
				bestCandidateDistance = null
				for child in @getChildren()
					distance = token.position.getDistance(child.coordinates)
					if !bestCandidateDistance? or distance < bestCandidateDistance
						bestCandidateDistance = distance
						bestCandidate = child
				if child?
					@emitTo(token.nodeId, 'token.candidate', distance, child.id)

		# Is called when a node holding a token, receives other candidate nodes for the token
		#
		# @param peer [Peer] The last routing peer
		# @param distance [Float] Distance from the candidate to the token
		# @param nodeId [String] Node id of the candidate
		#
		_onTokenCandidate: ( peer, distance, nodeId ) =>
			if @token?
				unless @token.candidates?
					@token.candidates = []
				candidate = {}
				candidate.distance = distance
				candidate.nodeId = nodeId
				@token.candidates.push(candidate)

		# Picks a new owner of the token. If the new owner is self, then it becomes a supernode
		#
		# @return[Node] Return a new owner of the token
		#
		_pickNewTokenOwner: ( ) ->
			if @token?
				bestCandidateDistance = null
				for candidate in @token.candidates ? []
					if !bestCandidateDistance? or candidate.distance < bestCandidateDistance
						bestCandidateDistance = candidate.distance
						bestCandidate = candidate

				if bestCandidate?
					console.log "Best Candidate is " + bestCandidate.nodeId + " with distance " + bestCandidateDistance
					if bestCandidate.nodeId is @id
						if not @isSuperNode
							@setSuperNode(true)
					else
						@emitTo(bestCandidate.nodeId,'token.add', @token.serialize())
						@token = null
						if @isSuperNode
							@setSuperNode(false)
				else
					if not @isSuperNode
						@setSuperNode(true)

		# Look up for a better supernode for your children
		#
		_lookForBetterSupernode: () =>
			siblings = @getSiblings()
			children = @getChildren()
			if @isSuperNode and siblings.length > 0 and children.length > 0
				for child in children
					bestCandidateDistance = null
					for parent in siblings
						distance = parent.coordinates.getDistance(child.coordinates)
						if !bestCandidateDistance? or distance < bestCandidateDistance
							bestCandidateDistance = distance
							parentCandidate = parent
					if parentCandidate? and bestCandidateDistance < child.latency * superNodeSwitchThreshhold
						child.emit('peer.parentCandidate', parentCandidate.id)

		# Switches a parent when a superNode suggest a better supernode			
		#
		# @param peer [Peer] The last routing peer
		# @param parentCandidateId [String] Id of the suggested supernode
		#
		_onPeerParentCandidate: (_peer, parentCandidateId) =>
			peer = @getPeer(parentCandidateId)
			if peer?
				@_pickParent([peer])
			else
				peer = @connect(parentCandidateId)
				peer.on('channel.opened', () =>
					@_pickParent([peer])
				)

		# Removes all timers
		#
		removeIntervals: ( ) ->
			for timer in @timers
				clearTimeout(timer)