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
	'library/helpers/mixable'
	'library/helpers/mixin.eventbindings'

	'library/node'
	'library/models/remote.server'
	'library/models/remote.peer'
	'library/models/message'
	'library/models/token'

	'library/models/collection'
	'library/models/vector'

	'underscore'

	], ( Mixable, EventBindings, Node, Server, Peer, Message, Token, Collection, Vector, _ ) ->

	# Constructs a new structured node.
	#
	class Node.Structured extends Node

		type: 'node.structured'

		_updatePositionInterval : 2000
		_ensureNetworkIntegrityInterval : 10000
		_recommendParentInterval: 10000
		_demotionTimeout: 11000
		_tokenInfoTimeout: 3000
		_pingCandidateTimeout : 1000

		_coordinateDelta : 1			# while updating coordinates
		_maxChildren : 4				# maximum amount of children, changing dynamically
		_foundationNodes : 3			# a minimum amount of supernodes to connect
		_superNodeSwitchThreshold : 0.7 # while recommending a better superNode
		_tokenSwitchThreshold : 0.7 	# while selecting a better token
		_tokenMoveThreshold : 4			# while requesting a token candidate
		_superNodeFoundation: 3			# a minimum amound of superNodes


		position : new Vector((Math.random()-0.5)*4, (Math.random()-0.5)*4, (Math.random()-0.5)*4)

		# Initializes Vivaldi and Popcorn on top of the unstructured node
		#
		initialize: () ->

			window.onbeforeunload = () =>
				@exitNetwork()
				return undefined

			@timers = []
			@timers.push(setInterval(@_updatePosition, @_updatePositionInterval))
			@timers.push(setInterval(@_ensureNetworkIntegrity, @_ensureNetworkIntegrityInterval))
			@timers.push(setInterval(@_recommendParent, @_recommendParentInterval))

			@isSuperNode = false
			@_parent = null

			@token = null
			@_tokens = new Collection()

			@server.on('connect', @_enterNetwork)
			@_peers.on
				'channel.opened': ( peer ) =>
					peer.query('isSuperNode', ( superNode ) =>
						if superNode? then peer.isSuperNode = superNode
					)
				'disconnect': @_onPeerDisconnect

			@onReceive
				'peer.abandonParent': ( id ) =>
					if child = @getChild(id)
						@removeChild(child)
				'peer.abandonChild': ( id ) =>
					if @_parent?.id is id
						@removeParent()
				'peer.addSibling': ( id ) =>
					if peer = @getPeer(id)
						@addSibling(peer, false)
				'peer.removeSibling': ( id ) =>
					if sibling = @getSibling(id)
						@removeSibling(sibling)
				'peer.setSuperNode': @_onPeerSetSuperNode
				'peer.recommendParent': @_onPeerRecommendParent

				'token.receive': @_onTokenReceived
				'token.info': @_onTokenInfo
				'token.requestCandidate': @_onTokenRequestCandidate
				'token.candidate': @_onTokenCandidate
				'token.die': @_onTokenDied

			@onQuery
				'ping': ( callback ) =>
					callback 'pong', @position.serialize(), @isSuperNode, @token?.serialize()
				'position': ( callback ) =>
					callback @position.serialize()
				'isSuperNode': ( callback ) =>
					callback @isSuperNode
				'siblings': ( callback ) =>
					callback @getSiblings().map( ( peer ) ->
						id: peer.id
					)
				'peer.requestAdoption': ( callback, id ) =>
					if @isSuperNode and child = @getPeer(id)
						@addChild(child)
						callback true
					else
						callback false
				'info': ( callback ) =>
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

		# Relays a message to other nodes. If the intended receiver is not a direct
		# neighbor, we route the message through other nodes in an attempt to reach
		# the destination.
		#
		# @param message [Message] the message to relay.
		#
		relay: ( message ) ->
			# If the message is a broadcast, send it to all connected peers.
			if message.to is '*'
				peer.send(message) for peer in @getPeers() when peer.id not in message.route and peer.role isnt Peer.Role.None

			# If the message is intended for the server, send it there.
			else if message.to is 'server'
				@server.send(message)

			# If we are connected to the intended receiver, send it there.
			else if peer = @getPeer(message.to)
				peer.send(message)

			# Try and route the message via our parent.
			else if parent = @getParent()
				parent.send(message)

			# When we're supernode, route the message via our peers.
			else if @isSuperNode
				sibling.send(message) for sibling in @getSiblings() when sibling.id not in message.route

			# If all else fails, route the message via the server.
			else @server.send(message)

		# Sets a peer as the parent node of this node.
		#
		# @param peer [Peer] the peer to set as parent
		# @param callback [function] is called with a parameter if a node is accepted or not
		#
		setParent: ( peer, callback ) ->
			if @isSuperNode
				callback?(false)
				return

			peer.query('peer.requestAdoption', @id, ( accepted ) =>
				unless accepted
					callback?(false)

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
			console.log 'removing parent ' + @_parent.id
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

		# Set this node to be supernode or not. When we're set to
		# become supernode, we set all connected supernodes as siblings
		# and create a token if we don't have one yet. If we're demoted
		# from supernode status, we remove our token, remove our siblings
		# and advice a new parent to all children.
		#
		# @param superNode [Boolean] wether or not to become supernode.
		#
		setSuperNode: (superNode, exit = false) ->
			if @isSuperNode is superNode
				return

			console.log "Supernode: #{superNode}, having token #{@token?} and children #{@getChildren().length}"
			@isSuperNode = superNode

			@server.emit('setSuperNode', superNode)
			@broadcast('peer.setSuperNode', @id, superNode)
			@trigger('setSuperNode', superNode)

			if @isSuperNode
				# If we have a parent, remove it.
				if @_parent?
					peer = @_parent
					@removeParent()

				# Set all connected supernodes as siblings.
				@addSibling(peer) for peer in @getPeers() when peer.isSuperNode

				# If we don't have a token, create one.
				unless @token?
					@token = new Token()
					@token.nodeId = @id
					@token.position = @position

			else
				# If we have a token, remove it.
				if @token?
					@broadcast('token.die', @token.serialize())
					console.log "I quit. Sending token.die", @token.id
					@token = null

				# Remove all siblings.
				for sibling in @getSiblings()
					@removeSibling(sibling)

				# Recommend a new parent to all children, and then
				# remove them.
				@_recommendParent(false)
				for child in @getChildren()
					@removeChild(child)

				# Select a new parent if not exiting
				if not exit
					@_selectParent()

		# Is called when a peer disconnects. Will make sure we handle this
		# disconnect in the appropriate manner.
		#
		# @param peer [Peer] the peer that disconnected.
		# @private
		#
		_onPeerDisconnect: ( peer ) =>
			if peer is @_parent
				@removeParent()
			else if peer.role is Peer.Role.Sibling
				@removeSibling(peer)
			else if peer.role is Peer.Role.Child
				@removeChild(peer)
			obsoleteTokens = _(@_tokens).filter( ( token ) => token.nodeId is peer.id)
			@removeToken(token) for token in obsoleteTokens

		# Is called when a peer switches supernode status. We will connect
		# to all new supernodes when we're supernode.
		#
		# @param id [String] the string id the of the peer
		# @param superNode [Boolean] the new supernode status of the peer
		# @private
		#
		_onPeerSetSuperNode: ( id, superNode ) =>
			unless peer = @getPeer(id)
				if superNode and @isSuperNode
					peer = @connect(id, ( success ) =>
						if success
							peer.isSuperNode = superNode
							@addSibling(peer)
					)
			else
				peer.isSuperNode = superNode
				if @isSuperNode and superNode
					@addSibling(peer)

		# Attempts to enter the network by requesting a list of supernodes
		# and selecting and connecting to a parent from the list.
		# @private
		#
		_enterNetwork: ( ) =>

			if @isSuperNode or @_parent?
				return

			# Recursive submethod attempt connections to a list
			# of nodes untill success.
			connectParent =  ( superNodes ) =>
				# If no available supernodes, we promote ourself.
				if superNodes.length is 0
					@setSuperNode(true)
					@trigger('joined')
					return

				# We pick a random supernode from the list.
				i = _.random(0, superNodes.length - 1)
				superNode = superNodes[i]
				superNodes.splice(i, 1)

				# If we're connected, just set as parent.
				if peer = @getPeer(superNode.id)
					@setParent(peer, ( accepted ) =>
						if accepted
							@trigger('joined')
						else
							connectParent(superNodes)
					)

				# Else, first connect, then set as parent.
				else
					peer = @connect(superNode.id, ( success ) =>
						unless success
							connectParent(superNodes)
							return

						@setParent(peer, ( accepted ) =>
							if accepted
								@trigger('joined')
							else
								connectParent(superNodes)
						)
					)
			# Query the server for nodes, and pass attempt to connect to supers.
			@server.query('nodes', 'node.structured', ( nodes ) =>
				if nodes?
					superNodes = _(nodes).filter( ( node ) -> node.isSuperNode)
					superNodes = _(superNodes).filter( ( node ) => node.id isnt @id)
					connectParent(superNodes)
			)

		# Safely exit network
		#
		exitNetwork: () =>

			@clearIntervals()

			# Break all relationships
			if @isSuperNode
			 	@setSuperNode(false, true)

			@server.disconnect()


			# Disconnect from all peers
			for peer in @getPeers()
				@removePeer(peer)

		# Selects the supernode with the lowest latency and attempts to connect.
		# If this fails, try the next lowest latency.
		# @private
		#
		_selectParent: ( ) ->

			if @isSuperNode or @_parent?
				return

			# Recursive submethod attempt connections to a list
			# of nodes untill success.
			requestParent = (superNodes) =>
				# If no supernode is left, request from the server.
				if superNodes.length is 0
					@_enterNetwork()
					return

				# Connect to the lowest latency node.
				superNode = superNodes.shift()
				@setParent(superNode, (accepted) =>
					unless accepted
						requestParent(superNodes)
				)

			# Compile a list of connected supernodes and sort by latency.
			superNodes = _(@getPeers()).filter( (peer) -> peer.isSuperNode)
			superNodes = _(superNodes).sortBy( (peer) -> peer.latency)
			requestParent(superNodes)

		# Ensures that the foundation of this node remains valid. Will do  this
		# by connecting to supernodes when required, or setting a parent when we
		# don't have one.
		# @private
		#
		_ensureNetworkIntegrity: () =>
			@_checkForInconsistencies()

			if not @isSuperNode and not @_parent?
				return

			# Request all nodes from the server and set all supernodes as siblings.
			if @isSuperNode

				@server.query('nodes', 'node.structured', ( nodes ) =>
					nodes = _(nodes).filter( ( node ) => node.id isnt @id)
					superNodes = _(nodes).filter( ( node ) -> node.isSuperNode)

					if superNodes.length > @_superNodeFoundation
						@_maxChildren = 8
					else
						@_maxChildren = 4

					# Ensure there are always 3 superNodes available
					if @getSiblings().length < 2
						siblingsNeeded = Math.min(@_superNodeFoundation - 1 - @getSiblings().length , nodes.length)
						while siblingsNeeded isnt 0
							@_distributeToken()
							siblingsNeeded--

					if superNodes.length is 0
						return

					# If a node has no children, start a timer to become a normal node
					if @getChildren().length is 0 and superNodes.length >= @_superNodeFoundation
						@_demotionTimer = setTimeout( () =>
							@setSuperNode(false)
						, @_demotionTimeout)

					for superNode in superNodes
						( ( superNode ) =>
							if peer = @getPeer(superNode.id)
								@addSibling(peer)
							else
								peer = @connect(superNode.id, ( success ) =>
									if success
										@addSibling(peer)
									else
										console.warn "can not connect to ", peer.id
								)
						) (superNode)


				)

			# Ensure we are connected to enough supernodes to aid us in finding
			# our correct position in the network and to catch our fall we we
			# lose our parent.
			else
				for peer in @getPeers()
					unless peer.isSuperNode then @removePeer(peer)

				current = _(@getPeers()).filter( (peer) -> peer.isSuperNode).length
				needed = @_foundationNodes - current
				if needed <= 0
					return

				@_parent.query('siblings', ( superNodes ) =>
					if not superNodes? or superNodes.length is 0
						return

					superNodes = _(superNodes).filter( ( node ) => not @getPeer(node.id)?)
					n = Math.min(needed, superNodes.length)
					while superNodes.length > n
						i = _.random(0,superNodes.length-1)
						superNodes.splice(i, 1)

					@connect(superNode.id) for superNode in superNodes
				)

		# Check for inconsistencies in the network such as broken relationships
		# @private
		#
		_checkForInconsistencies: () =>

			if @isSuperNode
				# Ensure all siblings are superNodes and vice versa
				for sibling in @getSiblings()
					if !sibling.isSuperNode
						@removeSibling(sibling)

				superNodes = _(@getPeers()).filter( ( node ) -> node.isSuperNode)
				for superNode in superNodes
					unless @getSibling(superNode.id)?
						@addSibling(superNode)

				# Children automatically checked by siblings guarante

				# Ensure we have no parent
				if @_parent?
					@removeParent()

				if not @token?
					@setSuperNode(false)

			else
				# Make sure we have a parent when we need one.
				if not @_parent?
					@_selectParent()

				# Make sure we have no siblings
				for sibling in @getSiblings()
					@removeSibling(sibling)

				# Make sure we have no children
				for child in @getChildren()
					@removeChild(child)

		# Updates all peers positions to be able to determine the nearest peers
		#
		# @private
		_updatePosition: ( ) =>
			i = 0
			for peer in @getPeers()
				( ( peer ) =>
					peer.ping( ( latency, position, isSuperNode, tokenString ) =>
						peer.position = Vector.deserialize(position)
						peer.isSuperNode = isSuperNode

						if tokenString?
							token = Token.deserialize(tokenString)
							@addToken(token)

						i++
						if i is @getPeers().length
							@_computePosition()
					)
				) ( peer )

		# Computes our position in the network from the positions of our neighbours
		# and the latency to them. This implements the vivaldi network coordinates:
		# @see http://en.wikipedia.org/wiki/Vivaldi_coordinates
		# @private
		_computePosition: ( ) ->
			for peer in @getPeers()
				direction = peer.position.subtract(@position)				# Vector to peer
				distance = peer.position.getDistance(@position)				# Distance between node and peer
				error = distance - peer.latency								# Difference between distance and Latency

				direction = direction.unit()								# Make direction into unit vector
				displacement =  direction.scale(error * @_coordinateDelta)	# Calculate displacement
				@position = @position.add( displacement )					# Calculate new position

				@_coordinateDelta = Math.max(0.05, @_coordinateDelta - 0.025)

			if @token?
				@token.position = @position
				@_computeTokenTargetPosition()

		# Recommends a parent to our children. We do this by checking which sibling is closest to
		# the child. We can include ourselves or not when we want to get rid of all our children.
		#
		# @param includeSelf [Boolean] wether or not to include ourselves in the recommendation.
		# @private
		_recommendParent: ( includeSelf = true ) =>

			siblings = @getSiblings()
			children = @getChildren()

			if not @isSuperNode or children.length is 0 or siblings.length is 0
				return

			for child in children when child.position?
				closestSuperNode = null
				closestDistance = Infinity

				for sibling in siblings when sibling.position?
					distance = child.position.getDistance(sibling.position)
					if distance < closestDistance
						closestDistance = distance
						closestSuperNode = sibling

				if closestDistance < child.position.getDistance(@position) * @_superNodeSwitchThreshold or not includeSelf
					child.emit('peer.recommendParent', closestSuperNode.id)

		# Is called when we receive a parent recommendation of our parent. Will attempt to
		# set the other supernode as parent.
		#
		# @param id [String] the string identifier of the recommended parent.
		# @private
		_onPeerRecommendParent: ( id ) =>

			if @isSuperNode
				return

			if peer = @getPeer(id)
				@setParent(peer)
			else
				peer = @connect(id, ( success ) =>
					if success
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


		# Groups tokens by Node id
		#
		groupTokens: () ->
			groupedTokens = {}
			for token in @_tokens
				if groupedTokens[token.nodeId]?
					groupedTokens[token.nodeId]++
				else
					groupedTokens[token.nodeId] = 1
			return groupedTokens

		# Creates a new token and passes it on to a random child.
		# @private
		_distributeToken: ( ) =>
			groupedTokens = @groupTokens()
			children = _(@getChildren()).filter( ( child ) => not groupedTokens[child.id])

			if children.length is 0
				return

			token = new Token()
			randomChild = children[_.random(0,children.length-1)]
			randomChild.emit('token.receive', token.serialize())
			console.log  randomChild.id +  " received a token with id", token.id

		# Is called when we received a token. This will start the token hop
		# process.
		#
		# @param tokenString [String] a string representation of the received token.
		# @private
		_onTokenReceived: ( tokenString, message ) =>
			if @token?
				@broadcast('token.die', tokenString)
				return

			@token = Token.deserialize(tokenString)
			console.log "received token from node #{message.from} with id ", @token.id
			@removeToken(@token)
			@token.nodeId = @id
			@token.position = @position

			@broadcast('token.info', @token.serialize(), true)

			setTimeout(( ) =>
				@_computeTokenTargetPosition()
			, @_tokenInfoTimeout)

		# Is called when we received information about a token. We will store this
		# information and return our info on own token if we have one.
		#
		# @param tokenString [String] a string representation of the token.
		# @param instantiate [Boolean] wether or not to respond.
		# @private
		_onTokenInfo: ( tokenString, instantiate, message ) =>

			token = Token.deserialize(tokenString)
			#console.log "received info from node #{message.from} about token with id ", token.id
			@addToken(token)

			if @token? and instantiate
				@emitTo(token.nodeId, 'token.info', @token.serialize(), false)

		# Is called when a token is killed. We will destroy any stored information
		# on the token.
		#
		# @param tokenString [String] a string representation of the token.
		# @private
		_onTokenDied: ( tokenString, message ) =>
			token = Token.deserialize(tokenString)
			#console.log "Received dead token from node #{message.from} with id ", token.id
			@removeToken(token)

		# Computes the desired position of the token from the positions of other tokens,
		# and requests candidates closer to this desired position then ourselves.
		# @private
		_computeTokenTargetPosition: ( ) ->
			unless @token?
				return

			force = Vector.createZeroVector(@position.length)
			directions = []
			for token in @_tokens
				direction = @position.subtract(token.position)		# Difference between self and other Token
				directions.push(direction)
				force = force.add(direction)						# Sum all token differences

			if force.getLength() isnt 0
				directions = _(directions).sortBy( (direction) -> direction.getLength())
				modalDirection = Math.floor(directions.length / 2)
				scaledModalDirectionLength = directions[modalDirection].getLength() / 2
				force = force.scale(scaledModalDirectionLength / force.getLength())

			@token.targetPosition = @token.position.add(force)
			magnitude = @position.getDistance(@token.targetPosition)

			if magnitude > @_tokenMoveThreshold and not @isSuperNode
				@token.candidates = []
				@broadcast('token.requestCandidate', @token.serialize())

				setTimeout( ( ) =>
					@_selectTokenOwner()
				, @_tokenInfoTimeout)
			else
				@_selectTokenOwner()

		# Is called when we receive a candidate request for a token. We will propose our child closest
		# to the target position of the token.
		#
		# @param tokenString [String] a string representation of the token.
		# @private
		_onTokenRequestCandidate: ( tokenString ) =>
			unless @isSuperNode
				return

			token = Token.deserialize(tokenString)
			@addToken(token)

			closestChild = null
			closestDistance = Infinity

			groupedTokens = @groupTokens()
			children = _(@getChildren()).filter( ( child ) => not groupedTokens[child.id])

			for child in children when child.position?
				distance = child.position.getDistance(token.targetPosition)
				if distance < closestDistance
					closestDistance = distance
					closestChild = child

			if closestChild?
				@emitTo(token.nodeId, 'token.candidate', closestChild.id, distance)

		# Is called when we receive a candidate for our token. We will store this
		# information in the token.
		#
		# @param id [String] the string identifier of the candidate
		# @param distance [Float] the distance to our token's target position
		# @private
		_onTokenCandidate: ( id, distance ) =>
			unless @token?
				return

			candidate =
				id: id
				distance: distance

			@token.candidates.push(candidate)

		# Selects the best candidate from all token candidates and passes our
		# token to this candidate.
		# @private
		_selectTokenOwner: ( ) =>
			unless @token?
				return

			closestCandidate = null
			closestDistance = Infinity

			for candidate in @token.candidates
				if candidate.distance < closestDistance * @_tokenSwitchThreshold
					closestDistance = candidate.distance
					closestCandidate = candidate.id
			@token.candidates = []

			ownDistance = @position.getDistance(@token.targetPosition)
			if closestCandidate? and closestCandidate isnt @id and ownDistance > closestDistance
				console.log "best candidate is #{closestCandidate}, distance is #{closestDistance}"
				@token.candidates = []
				@emitTo(closestCandidate, 'token.receive', @token.serialize())

				@token = null
				if @isSuperNode
					@setSuperNode(false)

			else
				@token.candidates = []
				@setSuperNode(true)

		# Remove all previously set intervals to prevent errors when an object is destroyed
		#
		clearIntervals: () ->
			for timer in @timers
				clearTimeout(timer)
