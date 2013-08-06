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
	'public//library/models/remote.server'
	'public//library/models/remote.peer'
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
		#_selectParentInterval: 2000
		_updateFoundationNodesInterval : 5000

		_pingCandidateTimeout : 1000
		_coordinateDelta : 1
		_maxChildren : 4
		_foundationNodes : 5
		

		position : new Vector(Math.random()-0.5, Math.random()-0.5, Math.random()-0.5)

		initialize: () ->


			@timers = []
			setInterval(@_updatePosition, @_updatePositionInterval)
			setInterval(@_updateFoundationNodes, @_updateFoundationNodesInterval)


			@_parent = null
			@isSuperNode = false

			@token = null

			@server.on('connect', @_enterNetwork)
			@_peers.on
				'channel.opened': (peer) =>
					peer.query('isSuperNode', ( superNode ) => peer.isSuperNode = superNode)
				'disconnect': @_onPeerDisconnect
				'peer.abandonParent': (_peer, id) =>
					if child = @getChild(id)
						@removeChild(child)
				'peer.abandonChild': (_peer, id) =>
					if @_parent?.id is id
						@removeParent()
				'peer.addSibling': (_peer, id) =>
					if peer = @getPeer(id)
						@addSibling(peer, false)
				'peer.removeSibling': (_peer, id) =>
					if sibling = @getSibling(id)
						@removeSibling(sibling)
				'peer.setSuperNode': @_onPeerSetSuperNode


		# Sets a peer as the parent node of this node.
		#
		# @param peer [Peer] the peer to set as parent
		# @param callback [function] is called with a parameter if a node is accepted or not
		#
		setParent: ( peer, callback ) ->

			if @isSuperNode #@_parent.id is peer.id
				callback(false)
				return

			peer.query('peer.requestAdoption', @id, (accepted) =>
				if accepted and not @token? and not @isSuperNode
					if @_parent?
						@removeParent()

					peer.role = Peer.Role.Parent
					@_parent = peer
					callback(true)
				else
					peer.emit('peer.abandonParent', @id)
					peer.role = Peer.Role.None
					callback(false)
			)

		# Removes the parent peer of this node.
		#
		# @return [Peer] the parent peer
		#
		removeParent: ( ) ->
			@_parent.emit('peer.abandonParent', @id)
			@_parent.role = Peer.Role.None
			@_parent = null

			unless @isSuperNode
				@_selectParent()

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
			if @getChildren().length > @_maxChildren
				console.log "generateToken()"
				#_(@generateToken).defer()

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

			else
				for sibling in @getSiblings()
					@removeSibling(sibling)
				for child in @getChildren()
					@removeChild(child)
				@_selectParent()

		_onPeerDisconnect: (peer) =>
			if peer is @_parent
				@removeParent()
			else if peer.role is Peer.Role.Sibling
				@removeSibling(peer)
			else if peer.role is Peer.Role.Child
				@removeChild(peer)


		_onPeerSetSuperNode: (_peer, id, superNode) =>
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
					superNodes = _(superNodes).filter( (node) => not @getPeer(node.id)?)

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

		_computePosition:() ->
			for peer in @getPeers()
				direction = peer.position.subtract(@position)				# Vector to peer
				distance = peer.position.getDistance(@position)				# Distance between node and peer
				error = distance - peer.latency								# Difference between distance and Latency

				direction = direction.unit()								# Make direction into unit vector
				displacement =  direction.scale(error * @_coordinateDelta)	# Calculate displacement
				@position = @position.add( displacement )					# Calculate new position

				@_coordinateDelta = Math.max(0.05, @_coordinateDelta - 0.025)

			
