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
	'public/library/models/token'

	'public/library/models/collection'
	'public/library/models/vector'
	
	'underscore'

	], ( Mixable, EventBindings, Server, Peer, Message, Token, Collection, Vector, _ ) ->

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
		tokenThreshhold = 1

		superNodeSwitchThreshhold = 0.6 # Scaler: from 0 to 1. More is easier switching
		kickstartPeers = 3

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
			@_timers = []

			@server = new Server(@, @serverAddress)

			@server.on('peer.connectionRequest', @_onPeerConnectionRequest)
			@server.on('peer.setRemoteDescription', @_onPeerSetRemoteDescription)
			@server.on('peer.addIceCandidate', @_onPeerAddIceCandidate)
			@server.on('connect', @_enterNetwork)

			@coordinates = new Vector(Math.random(), Math.random(), Math.random())
			@coordinateDelta = 1

			@_peers.on('disconnect', @_onPeerDisconnect)
			@_peers.on('peer.addSibling', ( peer ) => @addSibling(peer, false))
			@_peers.on('peer.setSuperNode', @_onPeerSetSuperNode)
			@_peers.on('token.add', @_onTokenReceived)
			@_peers.on('token.hop', @_onTokenInfo)
			@_peers.on('token.info', @_onTokenInfo)
			@_peers.on('token.requestCandidate', @_onTokenRequestCandidate)
			@_peers.on('token.candidate', @_onTokenCandidate)
			@_peers.on('peer.parentCandidate', @_onPeerParentCandidate)
			@_peers.on('peer.abandonParent', ( peer ) => @removeChild(peer))
			

			@_timers.push(setInterval(@_updateCoordinates, 7500))
			@_timers.push(setInterval(@_lookForBetterSupernode, 15000))
			@staySuperNodeTimeout = null

			@runBenchmark()

			# # This will help us log errors. It makes 
			# # console.log print to both console and server.
			# # Logs can be retrieved at /log
			# console.rLog = console.log
			# console.log = ( args... ) ->
			# 	console.rLog.apply(@, args)
			# 	App.node.server.emit('debug', args)
			
		# Attempts to connect to a peer.
		#
		# @param id [String] the id of the peer to connect to
		# @param instantiate [Boolean] wether to instantiate the connection
		#
		connect: ( id, instantiate = true ) ->
			peer = new Peer(@, id, instantiate)
			@addPeer(peer)
			return peer

		# Removes all timers
		#
		removeIntervals: ( ) ->
			for timer in @_timers
				clearTimeout(timer)
			
		# Disconects a peer.
		#
		# @param id [String] the id of the peer to disconnect
		#
		disconnect: ( id ) ->
			@getPeer(id)?.disconnect()

		# Is called when a peers disconnects. If that peer was 
		# our parent, we pick a new parent.
		#
		# @param peer [Peer] the peer that disconnects
		#
		_onPeerDisconnect: ( peer ) =>
			console.log peer
			if peer is @getParent()
				candidates = _(@getPeers()).filter( ( p ) -> p.isSuperNode )
				@_pickParent(candidates)
			
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
			@_triggerStaySuperNodeTimeout()

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

		_triggerStaySuperNodeTimeout: () =>
			if @getChildren().length is 0
				clearTimeout(@staySuperNodeTimeout)
				@staySuperNodeTimeout = setTimeout( ( ) =>
					@_superNodeTimeout()
				, 20000)
				@_timers.push(@staySuperNodeTimeout)

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
					return _(@getChildren().concat(@getSiblings(), @getParent())).map( ( peer ) -> peer?.id )
				when 'peer.requestParent'
					if @isSuperNode
						child = @getPeer(args[0])
						console.log "hier is mijn nieuwe kind", child
						if child?
							@addChild(child)
							return true
					return false

		# Is called when a node enters a network. This will either
		# make the current node a supernode, when no other supernodes
		# are found, or it connect to a bunch of other supernodes
		# and pick the one with the lowest latency is parent.
		#
		_enterNetwork: ( ) =>
			@server.query('nodes', ( nodes ) =>
				superNodes = _(nodes).filter( ( node ) => node.isSuperNode )

				# If no supernodes present, become a supernode
				if superNodes.length is 0
					@token = new Token(@id, @id)
					@setSuperNode(true)

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
										@_pickParent()
								)
							)
						) ( peer )
			)

		# Recursive function that attempts to pick a parent from all
		# connected supernodes. If a parent request is refused,
		# this function calls itself with all candidates that have
		# not yet refused a parent request. 
		#
		_pickParent: ( candidates = null ) =>
			unless candidates?
				candidates = _(@getPeers()).filter( ( p ) => p.isSuperNode )
			if candidates.length > 0
				candidates = _(candidates).sortBy( 'latency' )
				candidate = candidates.shift()
				@setParent(candidate, ( accepted ) =>
					if accepted
						console.log("parent request to #{candidate.id} accepted")
						@trigger('hasParent', true)
					else
						console.log("parent request to #{candidate.id} denied")
						@_pickParent(candidates)
				)
			else
				@_enterNetwork()

		# Runs a benchmark to get the available resources on this node.
		#
		runBenchmark: () =>
			startTime = Date.now()
			endTime = Date.now()
			@benchmark.cpu = Math.round(endTime - startTime)

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
			@_timers.push(@_tokenRestTimeout)

		# Is called when a token hops. Sends a token information to the initiator
		#
		# @param peer [Peer] The last routing peer
		# @param tokenString [String] A serialised token
		# @param vectorString [String] Serialised coordinates of the holder of the token
		#
		_onTokenInfo: ( peer, tokenString, vectorString, instantiate = true ) =>
			token = Token.deserialize(tokenString)
			token.coordinates = Vector.deserialize(vectorString)
			@addToken(token)
			if @token? and instantiate
				@emitTo(token.nodeId, 'token.info', @token.serialize(), @coordinates.serialize(), false)

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
				# Ask other supernodes for their best child in neighboorhood of the tokenPosition
				@broadcast('token.requestCandidate', @token.serialize())
				setTimeout( ( ) =>
					@_pickNewTokenOwner()
				, @broadcastTimeout)
				@_timers.push(@broadcastTimeout)
			else
				@setSuperNode(true)

			return tokenMagnitude
		
		# Is called when a token magnitude is calculated. A supernode selects his 
		# best child as candidate for the token
		#
		# @param peer [Peer] The last routing peer
		# @param tokenString [String] A serialised token
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
					@token.candidates = new Array()
				candidate = new Object()
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

		# Applies Vivaldi alghoritm. Calculates the coordinates of a node
		#
		_updateCoordinates: ( ) =>
			console.log "hi"
			for peer in @getPeers()	
				direction = peer.coordinates.substract(@coordinates)		# Vector to peer
				distance = peer.coordinates.getDistance(@coordinates)		# Distance between node and peer
				error = distance - peer.latency								# Difference between distance and Latency

				direction = direction.unit()								# Make direction into unit vector
				displacement =  direction.scale(error * @coordinateDelta)	# Calculate displacement
				@coordinates = @coordinates.add( displacement )				# Calculate new coordinates
								
				@coordinateDelta = Math.max(0.05, @coordinateDelta - 0.025)

		# Look up for a better supernode for your children
		#
		_lookForBetterSupernode: () =>
			console.log "ho"
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

		# Switches a parent when a superNode suggest a better Supernode			
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
