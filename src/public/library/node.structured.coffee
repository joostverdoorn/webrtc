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

		_updatePositionInterval : 2000
		_updateFoundationNodesInterval : 10000
		_recommendParentInterval: 10000
		_demotionTimeout: 11000
		_tokenInfoTimeout: 3000

		_pingCandidateTimeout : 1000
		_coordinateDelta : 1
		_maxChildren : 4
		_foundationNodes : 5
		_superNodeSwitchThreshold : 0.7
		_tokenMoveThreshold : 1
		

		position : new Vector(Math.random()-0.5, Math.random()-0.5, Math.random()-0.5)

		initialize: () ->


			@timers = []
			setInterval(@_updatePosition, @_updatePositionInterval)
			setInterval(@_updateFoundationNodes, @_updateFoundationNodesInterval)
			setInterval(@_recommendParent, @_recommendParentInterval)


			@_parent = null
			@isSuperNode = false

			@token = null
			@_tokens = new Collection()


			@server.on('connect', @_enterNetwork)
			@_peers.on
				'channel.opened': (peer) =>
					peer.query('isSuperNode', ( superNode ) => peer.isSuperNode = superNode)
				'disconnect': @_onPeerDisconnect

			@onReceive
				'peer.abandonParent': (id) =>
					if child = @getChild(id)
						@removeChild(child)
				'peer.abandonChild': (id) =>
					if @_parent?.id is id
						@removeParent()
				'peer.addSibling': (id) =>
					if peer = @getPeer(id)
						@addSibling(peer, false)
				'peer.removeSibling': (id) =>
					if sibling = @getSibling(id)
						@removeSibling(sibling)
				'peer.setSuperNode': @_onPeerSetSuperNode
				'peer.recommendParent': @_onPeerRecommendParent

				'token.receive': @_onTokenReceived
				'token.info': @_onTokenInfo
				'token.requestCandidate': @_onTokenRequestCandidate
				'token.candidate': @_onTokenCandidate
				'token.die': @_onTokenDied

		# Responds to a request
		#
		# @param request [String] the string identifier of the request
		# @param args... [Any] any arguments that may be accompanied with the request
		# @param callback [Function] the callback to call with the response
		#
		query: ( request, args..., callback ) =>
			switch request
				when 'ping'
					callback 'pong', @position.serialize()
				when 'position'
					callback @position.serialize()
				when 'isSuperNode'
					callback @isSuperNode
				when 'siblings'
					callback @getSiblings().map( ( peer ) ->
						id: peer.id
					)
				when 'peer.requestAdoption'
					id = args[0]
					if @isSuperNode and child = @getPeer(id)
						@addChild(child)
						callback true
					else
						callback false
				when 'info'
					info =
						id: @id
						type: @type
						position: @position
						isSuperNode: @isSuperNode
						token: @token
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

		# Sets a peer as the parent node of this node.
		#
		# @param peer [Peer] the peer to set as parent
		# @param callback [function] is called with a parameter if a node is accepted or not
		#
		setParent: ( peer, callback ) ->

			if @isSuperNode
				callback?(false)
				return

			peer.query('peer.requestAdoption', @id, (accepted) =>
				if accepted and not @isSuperNode
					if @_parent?
						@removeParent()

					peer.role = Peer.Role.Parent
					@_parent = peer
					callback?(true)
				else
					peer.emit('peer.abandonParent', @id)
					peer.role = Peer.Role.None
					callback?(false)
			)

		# Removes the parent peer of this node.
		#
		# @return [Peer] the parent peer
		#
		removeParent: ( ) ->
			@_parent.emit('peer.abandonParent', @id)
			@_parent.role = Peer.Role.None
			@_parent = null

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
				console.log "joost is een naus"
				@removeParent()

			if @getSibling(peer)?
				@removeSibling(peer)

			peer.role = Peer.Role.Child
			if @_demotionTimer?
				clearTimeout(@_demotionTimer)
			if @getChildren().length > @_maxChildren
				_(@_distributeToken).defer()

		# Removes a peer as child node. Does not automatically close 
		# the connection but will make it a normal peer.
		#
		# @param peer [Peer] the peer to remove as child
		#
		removeChild: ( peer ) ->
			if peer.role is Peer.Role.Child
				peer.role = Peer.Role.None
				peer.emit('peer.abandonChild', @id)

			if @getChildren().length is 0
				@_demotionTimer = setTimeout( () =>
					@setSuperNode(false)
				, @_demotionTimeout)

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
				console.log "asdasd2323"
				@removeParent()

			if @getChild(peer)?
				@removeChild(peer)

			peer.role = Peer.Role.Sibling
			if instantiate and @isSuperNode
				peer.emit('peer.addSibling', @id)

		# Removes a peer as sibling node. Does not automatically close 
		# the connection but will make it a normal peer.
		#
		# @param peer [Peer] the peer to remove as sibling
		#
		removeSibling: ( peer ) ->
			if peer.role is Peer.Role.Sibling
				peer.role = Peer.Role.None
				peer.emit('peer.removeSibling', @id)

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

		setSuperNode: (superNode) ->
			if @isSuperNode is superNode
				return

			@isSuperNode = superNode

			@server.emit('setSuperNode', superNode)
			@broadcast('peer.setSuperNode', @id, superNode)
			@trigger('setSuperNode', superNode)

			if @isSuperNode
				if @_parent?
					peer = @_parent
					@removeParent()
					@addSibling(peer)
				@addSibling(peer) for peer in @getPeers() when peer.isSuperNode		
				unless @token?
					@token = new Token()
					@token.nodeId = @id
					@token.position = @position

			else
				for sibling in @getSiblings()
					@removeSibling(sibling)
				for child in @getChildren()
					@removeChild(child)
				@_selectParent()
				@broadcast('token.die', @token.serialize())
				@token = null

		_onPeerDisconnect: (peer) =>
			if peer is @_parent
				@removeParent()
			else if peer.role is Peer.Role.Sibling
				@removeSibling(peer)
			else if peer.role is Peer.Role.Child
				@removeChild(peer)


		_onPeerSetSuperNode: (id, superNode) =>
			unless peer = @getPeer(id)
				if superNode and @isSuperNode
					peer = @connect(id)
					peer.once('channel.opened', =>
						@addSibling(peer)
					)
			else
				peer.isSuperNode = superNode

		_enterNetwork: () =>

			if @isSuperNode or @_parent?
				return

			connectParent =  (superNodes) =>

				if superNodes.length is 0
					@setSuperNode(true)
					return

				i = _.random(0,superNodes.length-1)
				superNode = superNodes[i]
				superNodes.splice(i, 1)

				peer = @connect(superNode.id)
				peer.once('channel.opened', () =>
					@setParent(peer, (accepted) =>
						unless accepted
							connectParent(superNodes)
					)
				)

			@server.query('nodes', 'node.structured', (nodes) =>
				superNodes = _(nodes).filter( (node) -> node.isSuperNode)

				if superNodes.length is 0
					@setSuperNode(true)
					return

				connectParent(superNodes)

			)

		_selectParent: () ->

			if @isSuperNode or @_parent?
				return

			requestParent = (superNodes) =>

				if superNodes.length is 0
					@_enterNetwork()
					return

				superNode = superNodes.shift()

				@setParent(superNode, (accepted) =>
					unless accepted
						requestParent(superNodes)
				)

			superNodes = _(@getPeers()).filter( (peer) -> peer.isSuperNode)
			superNodes = _(superNodes).sortBy( (peer) -> peer.latency)
			requestParent(superNodes)

		_updateFoundationNodes: () =>


			if @isSuperNode
				@server.query('nodes', 'node.structured', (nodes) =>
					superNodes = _(nodes).filter( (node) -> node.isSuperNode)
					superNodes = _(superNodes).filter( (node) => not @getPeer(node.id)? and node.id isnt @id )

					if superNodes.length is 0
						return

					for superNode in superNodes
						( (superNode) =>
							peer = @connect(superNode.id)
							peer.once('channel.opened', () =>
								@addSibling(peer)
							)
						) (superNode)
				)

			else unless @_parent?
				@_enterNetwork()

			else
				current = _(@getPeers()).filter( (peer) -> peer.isSuperNode).length
				needed = @_foundationNodes - current
				if needed <= 0 
					return

				@_parent.query('siblings', (superNodes) =>
					if superNodes.length is 0
						return 

					superNodes = _(superNodes).filter( (node) => not @getPeer(node.id)?)
					n = Math.min(needed, superNodes.length)
					while superNodes.length > n
						i = _.random(0,superNodes.length-1)
						superNodes.splice(i, 1)

					@connect(superNode.id) for superNode in superNodes
				)

		_updatePosition: () =>
			i = 0
			for peer in @getPeers()
				( ( peer ) =>
					peer.ping( ( latency, position ) =>
						peer.position = Vector.deserialize(position)
						i++
						if i is @getPeers().length
							@_computePosition()
					)
				) ( peer )

		_computePosition: () ->
			for peer in @getPeers()
				direction = peer.position.subtract(@position)				# Vector to peer
				distance = peer.position.getDistance(@position)				# Distance between node and peer
				error = distance - peer.latency								# Difference between distance and Latency

				direction = direction.unit()								# Make direction into unit vector
				displacement =  direction.scale(error * @_coordinateDelta)	# Calculate displacement
				@position = @position.add( displacement )					# Calculate new position

				@_coordinateDelta = Math.max(0.05, @_coordinateDelta - 0.025)

			console.log "cieapo"
			if @token?
				@token.position = @position
				@_computeTokenTargetPosition()

		_recommendParent: () =>

			siblings = @getSiblings()
			children = @getChildren()

			if not @isSuperNode or children.length is 0 or siblings.length is 0
				return

			for child in children
				closestSuperNode = null
				closestDistance = Infinity
				for sibling in siblings
					distance = child.position.getDistance(sibling.position)
					if distance < closestDistance
						closestDistance = distance
						closestSuperNode = sibling
				if closestDistance < child.position.getDistance(@position) * @_superNodeSwitchThreshold
					child.emit('peer.recommendParent', closestSuperNode.id)


		_onPeerRecommendParent: (id) =>

			if @isSuperNode
				return

			if peer = @getPeer(id)
				@setParent(peer)
			else
				peer = @connect(id)
				peer.once('channel.opened', () =>
					@setParent(peer)
				)

		# Adds a token to the collection of foreign tokens
		#
		# @param [Token] A token to be added. This token can not be own token
		#
		addToken: ( token ) ->
			if @token?.id is token.id
				return

			@removeToken(token)
			@_tokens.add(token)

		# Remove token from a collection of tokens
		#
		# @param [Token] A token to be removed.
		#
		removeToken: ( token ) ->
			if oldToken = _(@_tokens).find( ( t ) -> token.id is t.id)
				@_tokens.remove(oldToken)


		_distributeToken: () =>
			token = new Token()
			children = @getChildren()
			randomChild = children[_.random(0,children.length-1)]
			randomChild.emit('token.receive', token.serialize())
			console.log  randomChild.id +  ' received a token'

		_onTokenReceived: (tokenString) =>
			if @token?
				return

			console.log tokenString
			@token = Token.deserialize(tokenString)
			@removeToken(@token)
			@token.nodeId = @id
			@token.position = @position

			@broadcast('token.info', @token.serialize())
			
			setTimeout(( ) =>
				@_computeTokenTargetPosition()
			, @_tokenInfoTimeout)

		_onTokenInfo: (tokenString, instantiate = true) =>
			token = Token.deserialize(tokenString)
			@addToken(token)

			if @token? and instantiate
				@emitTo(token.nodeId, 'token.info', @token.serialize(), false)

		_onTokenDied: (tokenString) =>
			token = Token.deserialize(tokenString)
			@removeToken(token)


		_computeTokenTargetPosition: () ->
			unless @token?
				return

			force = Vector.createZeroVector(@position.length)
			for token in @_tokens
				direction = @position.subtract(token.targetPosition)		# Difference between self and other Token
				direction.scale(2 / direction.getLength())
				force = force.add(direction)					# Sum all token differences

			console.log "asd"
			@token.targetPosition = @position.add(force)

			magnitude = @position.getDistance(@token.targetPosition)
			if magnitude > @_tokenMoveThreshold
				@broadcast('token.requestCandidate', @token.serialize())

				setTimeout( ( ) =>
					@_selectTokenOwner()
				, @_tokenInfoTimeout)
			else
				@_selectTokenOwner()



		_onTokenRequestCandidate: ( tokenString ) =>
			unless @isSuperNode
				return

			token = Token.deserialize(tokenString)

			closestChild = null
			closestDistance = Infinity
			
			for child in @getChildren()
				distance = child.position.getDistance(token.targetPosition)
				if distance < closestDistance
					closestDistance = distance
					closestChild = child

			if closestChild?
				@emitTo(token.nodeId, 'token.candidate', closestChild.id, distance)


		_onTokenCandidate: ( id, distance ) =>
			unless @token?
				return

			candidate =
				id: id
				distance: distance

			@token.candidates.push(candidate)

		_selectTokenOwner: ( ) =>
			unless @token?
				return

			closestCandidate = null
			closestDistance = Infinity

			for candidate in @token.candidates
				if candidate.distance < closestDistance
					closestDistance = candidate.distance
					closestCandidate = candidate.id

			console.log "best candidate is #{closestCandidate}, distance is #{closestDistance}"
			if closestCandidate? and closestCandidate isnt @id
				@emitTo(closestCandidate, 'token.add', @token.serialize())
				@token = null
				@setSuperNode(false)

			else
				@token.candidates = []
				@setSuperNode(true)





			# @token.force = tokenForce
			# @token.position = @coordinates.add(tokenForce)				# Calculate the new Token Position and save it in Token object
			# tokenMagnitude = @coordinates.getDistance(@token.position)










			


