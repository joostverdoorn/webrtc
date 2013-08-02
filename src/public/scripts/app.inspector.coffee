requirejs.config
	baseUrl: '../'

	shim:
		'underscore':
			exports: '_'

		'jquery':
			exports: '$'

		'socket.io':
			exports: 'io'

		'three':
			exports: 'THREE'

		'stats':
			exports: 'Stats'

	# We want the following paths for 
	# code-sharing reasons. Now it doesn't 
	# matter from where we require a module.
	paths:
		'public': './'

		'underscore': 'vendor/scripts/underscore'
		'jquery': 'vendor/scripts/jquery'
		'three': 'vendor/scripts/three'
		'stats': 'vendor/scripts/stats.min'
		'socket.io': 'socket.io/socket.io'

require [
	'scripts/app._'
	'library/models/remote.server'

	'three'
	'stats'

	'jquery'
	'underscore'
	], ( App, Server, Three, Stats, $, _ ) ->

	# Inspector app class. This will create and draw a 3d scene
	# containing all nodes and their connections.
	#
	class App.Inspector extends App

		type: 'inspector'
		serverAddress: ':8080/'

		nodes: []
		
		# Constructs a new inspector app. 
		#
		constructor: ( ) ->
			viewAngle = 45
			nearClip = 0.1
			farClip = 10000

			@_zoom = 1

			@_deltaX = 0
			@_deltaY = 0
			@_lastMouseX = 0
			@_lastMouseY = 0
			@_mouseDown = false		

			@_cameraAngle = new Three.Quaternion()

			# Connect to the server.
			@server = new Server(@, @serverAddress)

			# Create container element.
			container = document.createElement 'div'
			container.id = 'container'
			document.body.appendChild(container)

			# Get width and height of the window and determine aspect ratio.
			[width, height] = @setDimensions()
			aspectRatio = width / height

			# Create scene, camera and renderer.
			@scene = new Three.Scene()
			@camera = new Three.PerspectiveCamera(viewAngle, aspectRatio, nearClip, farClip)
			@camera.position = new Three.Vector3()
			@renderer = new Three.WebGLRenderer()

			@renderer.setSize(width, height)
			container.appendChild(@renderer.domElement)
			@scene.add(@camera)

			# Add lights to the scene.
			hemisphereLight = new THREE.HemisphereLight( 0xffffff, 0xaaaaaa, 1 );
			@scene.add(hemisphereLight)

			# Create projector for tracking mouse in 3d world
			@projector = new THREE.Projector();
			@label = $('<div class="label"></div>')
			$('body').append(@label)
			
			@label.hide()
			@label.css('position', 'absolute')

			# Set the last updated time to 0
			@_lastUpdateTime = 0

			# Add debug stats
			@stats = new Stats()
			@stats.domElement.style.position = 'absolute'
			@stats.domElement.style.top = '0px'
			@stats.domElement.style.left = '0px'
			container.appendChild(@stats.domElement)

			# Add axes
			xStart = new Three.Vector3(5000, 0, 0)
			xEnd = new Three.Vector3(-5000, 0, 0)
			yStart = new Three.Vector3(0, 5000, 0)
			yEnd = new Three.Vector3(0, -5000, 0)
			zStart = new Three.Vector3(0, 0, 5000)
			zEnd = new Three.Vector3(0, 0, -5000)

			xGeometry = new Three.Geometry()
			xGeometry.vertices.push(xStart)
			xGeometry.vertices.push(xEnd)
			xMaterial = new Three.LineBasicMaterial(color: 0xff0000)
			xLine = new Three.Line(xGeometry, xMaterial)
			@scene.add(xLine)

			yGeometry = new Three.Geometry()
			yGeometry.vertices.push(yStart)
			yGeometry.vertices.push(yEnd)
			yMaterial = new Three.LineBasicMaterial(color: 0x00ff00)
			yLine = new Three.Line(yGeometry, yMaterial)
			@scene.add(yLine)

			zGeometry = new Three.Geometry()
			zGeometry.vertices.push(zStart)
			zGeometry.vertices.push(zEnd)
			zMaterial = new Three.LineBasicMaterial(color: 0x0000ff)
			zLine = new Three.Line(zGeometry, zMaterial)
			@scene.add(zLine)

			# Various callbacks and the like.
			window.requestAnimationFrame(@update)
			$(window).resize(@setDimensions)
			
			$(window).mousemove ( event ) =>
				if @_mouseDown
					@_deltaX = event.clientX - @_lastMouseX
					@_deltaY = event.clientY - @_lastMouseY

					@_lastMouseX = event.clientX
					@_lastMouseY = event.clientY

				# Detect mouse intersects
				mouseX = ( event.clientX / window.innerWidth ) * 2 - 1
				mouseY = - ( event.clientY / window.innerHeight ) * 2 + 1
				vector = new THREE.Vector3( mouseX, mouseY, 0.5 )
				
				@projector.unprojectVector( vector, @camera )
				raycaster = new THREE.Raycaster( @camera.position, vector.sub( @camera.position ).normalize() )
				intersects = raycaster.intersectObjects( node.mesh for node in @nodes )
				
				if node = _(@nodes).find( ( node ) -> node.mesh is intersects[0]?.object )
					@label.html(node.id)
					@label.css('left', event.clientX)
					@label.css('top', event.clientY - 20)
					@label.show()
				else
					@label.hide()

			$(window).mousedown ( ) => 
				@_mouseDown = true
				@_lastMouseX = event.offsetX
				@_lastMouseY = event.offsetY

			$(window).mouseup ( ) => 
				@_mouseDown = false

			$(window).scroll ( event ) =>
				console.log event

			setInterval( =>
				@server.query('nodes', 'node.structured', true, @processNodesInfo)
			, 1000)

		# Sets the dimensions of the viewport and the aspect ration of the camera
		#
		# @return [[Integer, Integer]] a tuple of the width and height of the container
		#
		setDimensions: ( ) =>
			width = window.innerWidth
			height = window.innerHeight

			@renderer?.setSize(width, height)
			@camera?.aspect = width / height
			@camera?.updateProjectionMatrix()

			return [width, height]

		# Updates the scene, calling update on every node in the scene. Also 
		# requests a new animation frame to keep on updating.
		#
		# @param timestamp [Integer] the time that has elapsed since the first update
		#
		update: ( timestamp ) =>
			# Get time since last update and update all nodes.
			dt = (timestamp - @_lastUpdateTime) / 1000
			node.update(dt) for node in @nodes

			# Update camera position.
			if @_mouseDown
				width = window.innerWidth
				height = window.innerHeight

				yAngle = -(@_deltaX / width)  * Math.PI * 5
				zAngle = -(@_deltaY / height) * Math.PI * 5

				angle = new Three.Quaternion().setFromEuler(new Three.Euler(0, yAngle, zAngle, 'YXZ'))
				@_cameraAngle.multiply(angle)

			position = new Three.Vector3(-100 * @_zoom, 0, 0).applyQuaternion(@_cameraAngle)
			@camera.position.lerp(position, dt * 20)
			@camera.lookAt(new Three.Vector3(0, 0, 0))

			zVector = new Three.Vector3(1, 0, 0).applyQuaternion(new Three.Quaternion().setFromEuler(@camera.rotation))
			yVector = @camera.position.clone()
			@camera.up = new Three.Vector3().crossVectors(zVector, yVector).negate()

			# Render the scene.
			@renderer.render(@scene, @camera)

			# Update stats.
			@stats.update()

			# Set last update time and request a new animation frame.
			@_lastUpdateTime = timestamp
			window.requestAnimationFrame(@update)

		# Processes nodes information. Will update the nodes' position, state
		# and connected peers. Will add nodes not yet added and remove disconnected
		# nodes.
		#
		# @param nodesInfo [Array<Object>] an array of objects representing the nodes
		#
		processNodesInfo: ( nodesInfo ) =>
			for node in @nodes
				if nodeInfo = _(nodesInfo).find( ( nodeInfo ) -> nodeInfo.id is node.id)
					node.setInfo(nodeInfo)
					nodesInfo = _(nodesInfo).without(nodeInfo)
				else
					node.die()
					@nodes = _(@nodes).without(node)

			for nodeInfo in nodesInfo
				node = new Node(@, nodeInfo)
				@nodes.push(node)

		# Responds to a request
		#
		# @param request [String] the string identifier of the request
		# @param args... [Any] any arguments that may be accompanied with the request
		# @param callback [Function] the callback to call with the response
		#
		query: ( request, args..., callback ) ->
			switch request
				when 'ping'
					callback 'pong'
				when 'type'
					callback @type
				else
					callback null

	# Helper node display class. Contains information on a certain node in the network,
	# and draws it onto the scene.
	#
	class Node

		# Constructs and draws a new node.
		#
		# @param app [App] the app from which the node was constructed
		# @param nodeInfo [Object] an object representing this node
		#
		constructor: ( @app, nodeInfo ) ->
			@scene = @app.scene

			geometry = new Three.SphereGeometry(0.5, 6, 8)
			@mesh = new Three.Mesh(geometry)			
			@scene.add(@mesh)

			@peers = []
			@edges = []

			@setInfo(nodeInfo)

		# Removes this node from the scene.
		#
		die: ( ) ->
			@scene.remove(@mesh)
			@scene.remove(edge) for edge in @edges
			@scene.remove(@tokenMesh)
			@scene.remove(@tokenEdge)
			@edges = []

		# Updates this nodes' position and the lines to its connected nodes.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt ) ->
			if @position
				@mesh.position.lerp(@position, dt)

			@scene.remove(edge) for edge in @edges
			@edges = []

			for peer in @peers
				if peer.role is 'Child' or peer.role is 'Sibling'
					if node = _(@app.nodes).find( ( node ) -> node.id is peer.id )
						geometry = new Three.Geometry()
						geometry.vertices.push(@mesh.position)
						geometry.vertices.push(node.mesh.position)

						material = new Three.LineBasicMaterial(
							color: 0xff2222
							linewidth: 1
						)
						
						edge = new Three.Line(geometry, material)
						@edges.push(edge)
						@scene.add(edge)

			if @tokenMesh?
				@scene.remove(@tokenEdge) if @tokenEdge?
				geometry = new Three.Geometry()
				geometry.vertices.push(@mesh.position, @tokenMesh.position)
				material = new Three.LineDashedMaterial(color: 0xffff00)
				@tokenEdge = new Three.Line(geometry, material)
				@scene.add(@tokenEdge)
				@tokenMesh.position.lerp(@tokenPosition, dt)

		# Sets information of this node from a nodeInfo object. Used to update
		# the node's state or connected peers.
		#
		# @param nodeInfo [Object] an object representing this node
		#
		setInfo: ( nodeInfo ) ->
			@id = nodeInfo.id
			@isSuperNode = nodeInfo.isSuperNode
			@token = nodeInfo.token
			
			if @token?
				unless @tokenMesh?
					geometry = new Three.SphereGeometry(0.2, 6, 8)
					material = new THREE.MeshLambertMaterial( color:0xffff00 )
					@tokenMesh = new Three.Mesh(geometry, material)
					@tokenMesh.position.set(@token.position[0], @token.position[1], @token.position[2])			
					@scene.add(@tokenMesh)

				x = @token.position[0]
				y = @token.position[1]
				z = @token.position[2]
				@tokenPosition = new Three.Vector3(x, y, z)

			else
				@scene.remove(@tokenMesh)
				@scene.remove(@tokenEdge)			
				delete @tokenMesh
				delete @tokenEdge

			@peers = nodeInfo.peers

			# Set supernodes to display as red, normal nodes as green.
			if @isSuperNode then material = new THREE.MeshLambertMaterial( color:0xff0000 )
			else if @token then material = new THREE.MeshLambertMaterial( color:0xffff00 )
			else material = new Three.MeshLambertMaterial( color:0x00ff00 )

			@mesh.material = material

			# Update coordinates.
			x = nodeInfo.coordinates[0]
			y = nodeInfo.coordinates[1]
			z = nodeInfo.coordinates[2]
			@position = new Three.Vector3(x, y, z)

	window.App = new App.Inspector()