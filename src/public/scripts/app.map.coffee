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

		'orbitControls': [ 'three' ]

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
		'orbitControls': 'vendor/scripts/orbitControls'

require [
	'scripts/app._'
	'library/node.structured'

	'three'
	'stats'

	'jquery'
	'underscore'
	'orbitControls'
	], ( App, Node, Three, Stats, $, _ ) ->

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

			# Connect to the server.
			@node = new Node()
			@players = []

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
			@camera.position = new Three.Vector3(-1000, 0, 0)
			@renderer = new Three.WebGLRenderer()

			@renderer.setSize(width, height)
			container.appendChild(@renderer.domElement)
			@scene.add(@camera)

			# Add lights to the scene.
			hemisphereLight = new THREE.HemisphereLight( 0xffffff, 0xaaaaaa, 1 );
			@scene.add(hemisphereLight)

			# Add planet
			@_loader = new Three.JSONLoader()
			@_loader.load('/meshes/planet.js', ( geometry, material ) =>
				planet = new Three.Mesh(geometry, new Three.MeshFaceMaterial(material))
				@scene.add(planet)
			)

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

			# Add controls
			@controls = new Three.OrbitControls(@camera)

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

			@node.onReceive
				'player.died': ( id ) =>
					if player = _(@players).find( ( p ) -> p.id is id )
						player.die()
						@players = _(@players).without(player)
				'player.update': ( id, info, timestamp ) =>
					if player = _(@players).find( ( p ) -> p.id is id )
						player.applyInfo(info)
					else
						player = new Player(@, id)
						player.applyInfo(info)
						@players.push(player)
			
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
			player.update(dt) for player in @players

			# Update camera position.
			@controls.update()

			# Render the scene.
			@renderer.render(@scene, @camera)

			# Update stats.
			@stats.update()

			# Set last update time and request a new animation frame.
			@_lastUpdateTime = timestamp
			window.requestAnimationFrame(@update)
	
	class Player

		constructor: ( @app, @id ) ->
			@targetPosition = new Three.Vector3()

			geometry = new Three.SphereGeometry(2, 6, 8)
			material = new Three.MeshLambertMaterial( color:0x00ff00 )
			@mesh = new Three.Mesh(geometry, material)
			@app.scene.add(@mesh)

		update: ( dt ) ->
			@mesh.position.lerp(@targetPosition, dt * 2)

		die: ( ) ->
			@app.scene.remove(@mesh)

		applyInfo: ( info ) ->
			@targetPosition.fromArray(info.position)

	window.App = new App.Inspector()