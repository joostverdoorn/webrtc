requirejs.config
	baseUrl: '../'

	shim:
		'jquery':
			exports: '$'

		'three':
			exports: 'THREE'

		'stats':
			exports: 'Stats'

		'bootstrap': [ 'jquery' ]
		'qrcode': [ 'jquery' ]
		'jquery.plugins': [ 'jquery' ]

	# We want the following paths for 
	# code-sharing reasons. Now it doesn't 
	# matter from where we require a module.
	paths:
		'public': './'

		'underscore': 'vendor/scripts/underscore'
		'jquery': 'vendor/scripts/jquery'
		'bootstrap': 'vendor/scripts/bootstrap'
		'three': 'vendor/scripts/three'
		'qrcode': 'vendor/scripts/qrcode.min'
		'stats': 'vendor/scripts/stats.min'
		
require [
	'public/scripts/app._'
	'public/library/node'
	'public/library/node.structured'

	'public/scripts/models/world'
	'public/scripts/models/entity.player'
	'public/scripts/models/controller'

	'public/views/infoScreen'

	'jquery'
	'three'
	'stats'
	], ( App, ControllerNode, Node, World, Player, Controller, InfoScreen, $, Three, Stats ) ->

	# This game class implements the node structure created in the library.
	# It uses three.js for the graphics.
	#
	class App.Game extends App

		viewAngle = 45
		nearClip = 0.1
		farClip = 10000

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@inputHandler = new Controller()
			@infoScreen = new InfoScreen $('#overlay'), false
			@infoScreen.on('controllerType', ( type ) =>
					switch type
						when 'mouse'
							@inputHandler.selectInput(type)
							@infoScreen.showInfoScreen(type)

							@startGame()
						when 'mobile'
							# Should be called when a user decides to connect his mobile phone
							@createControllerNode()
				)

			@container = document.createElement 'div'
			@container.id = 'container'
			document.body.appendChild @container
			@container = $('#container')
			[width, height] = @setDimensions()

			@scene = new Three.Scene()
			@renderer = new Three.WebGLRenderer({antialias: true})
			@renderer.setSize(width, height)
			@renderer.shadowMapEnabled = true
			@container.append(@renderer.domElement)

			@aspectRatio = width / height
			@camera = new Three.PerspectiveCamera(@viewAngle, @aspectRatio, @nearClip, @farClip)
			@cameraRaycaster = new Three.Raycaster()

			@scene.add(@camera)
			@scene.fog = new Three.FogExp2( 0xaabbff, 0.0015 );

			@_lastUpdateTime = 0

			# Create sky dome
			@sky = new THREE.Mesh( new THREE.SphereGeometry( 1500, 6, 8 ), new THREE.MeshBasicMaterial( { map: THREE.ImageUtils.loadTexture( '/images/sky.jpg' ) } ) )
			@sky.scale.x = -1;
			@scene.add( @sky )

			@stats = new Stats()
			@stats.domElement.style.position = 'absolute'
			@stats.domElement.style.top = '20px'
			@stats.domElement.style.left = '20px'
			@container.append(@stats.domElement)

			@world = new World(@scene)
			@node = new Node()

			@status = 0

			@node.server.on('connect', ( ) =>
				@node.server.off('connect')
				@status = 1
			)

			@node.on('joined', =>
				@node.off('joined')
				@infoScreen.showWelcomeScreen()
				@status = 2
			)

			@node.on('left', =>
				console.log 'Left the network'
			)

			@node.onReceive('player.list', ( list ) =>
				@world.createPlayer(id, info) for id, info in list
			)

			@node.onReceive('player.joined', ( id, info ) =>
				@world.createPlayer(id, info)
			)

			@node.onReceive('player.left', ( id ) =>
				@world.removePlayer(id)
			)

			@node.onReceive('player.died', ( id ) =>
				@world.removePlayer(id)
			)

			@node.onReceive('player.update', ( id, info, timestamp ) =>
				@world.applyPlayerInfo(id, info, timestamp)
			)

			@node.onReceive('player.fire', ( id, info, timestamp ) =>
				@world.createProjectile(info, timestamp)
			)

			window.requestAnimationFrame(@update)
			$(window).resize(@setDimensions)

		# Sets the dimensions of the viewport and the aspect ration of the camera
		#
		# @return [[Integer, Integer]] a tuple of the width and height of the container
		#
		setDimensions: ( ) =>
			width = window.innerWidth
			height = window.innerHeight

			@renderer?.setSize(width, height)

			@aspectRatio = width / height
			@camera?.aspect = @aspectRatio
			@camera?.updateProjectionMatrix()

			return [width, height]

		# Spawns the player in the world.
		#
		# @param position [Three.Vector3] the position at which to spawn the player
		#
		createPlayer: ( position ) =>
			if @player
				return

			info = 
				position: position.toArray()

			@player = @world.createPlayer(@node.id, true, info)
			@player.on('fire', ( projectile ) => @node.broadcast('player.fire', @player.id, projectile.getInfo()))
			@node.broadcast('player.joined', @player.id, @player.getInfo())

			broadcastInterval = setInterval( ( ) =>
				@node.broadcast('player.update', @player.id, @player.getInfo())
			, 200)

			@player.on('die', ( position, velocity ) =>
					@_playerDied(broadcastInterval, position, velocity)
				)

		_playerDied: ( interval, position, velocity ) ->
			clearInterval(interval)
			@node.broadcast('player.died', @player.id)
			@player = null

			@infoScreen.show()
			@infoScreen.showPlayerDiedScreen()
			@startGame()

		# Updates the phyics for all objects and renders the scene. Requests a new animation frame 
		# to repeat this methods.
		#
		# @param timestamp [Integer] the time that has elapsed since the first requestAnimationFrame
		#
		update: ( timestamp ) =>
			dt = (timestamp - @_lastUpdateTime) / 1000     

			# Apply input to player.
			if @player?.cannon?			
				@player.fire() if @inputHandler.getFire()
				@player.boost = @inputHandler.getBoost()

				@player.flyLeft = @inputHandler.getFlyLeft()
				@player.flyRight = @inputHandler.getFlyRight()
				@player.flyForward = @inputHandler.getFlyForward()
				@player.flyBackward = @inputHandler.getFlyBackward()

				@player.cannon.rotateLeft = @inputHandler.getCannonRotateLeft()
				@player.cannon.rotateRight = @inputHandler.getCannonRotateRight()
				@player.cannon.rotateUpward = @inputHandler.getCannonRotateUpward()
				@player.cannon.rotateDownward = @inputHandler.getCannonRotateDownward()

			# Update the world
			@world.update(dt, @player)

			# Set the camera to follow the player
			if @player? and @player.cannon?
				# Get the direction of the camera, and apply cannon and player rotations to it.
				cameraDirection = new Three.Vector3(-1, 0, 0)
				cameraDirection.applyQuaternion(new Three.Quaternion().setFromEuler(@player.cannon.rotation.clone()))
				cameraDirection.applyQuaternion(new Three.Quaternion().setFromEuler(@player.rotation.clone()))

				# Get the target position of the camera
				targetPosition = @player.position.clone().add(cameraDirection.multiplyScalar(80))

				currentLength = targetPosition.length()
				planetRadius = @world.planet.geometry.boundingSphere.radius
				if currentLength < planetRadius
					targetPosition2 = targetPosition.clone().multiplyScalar((planetRadius) / currentLength)
					@cameraRaycaster.set(targetPosition2, targetPosition2.clone().negate())
					intersects = @cameraRaycaster.intersectObject(@world.planet)
					for key, intersect of intersects
						surface = planetRadius - intersect.distance
						surface += 20		# Safe distance
						targetPosition.multiplyScalar(surface / currentLength)
						break

				# Ease the camera to the target position
				@camera.position.lerp(targetPosition, 1.5 * dt)

				# Set the upvector perpendicular to the planet surface and point the camera
				# towards the player
				@camera.up.set(@camera.position.x, @camera.position.y, @camera.position.z)
				@camera.lookAt(@player.position)

				# Update sky position
				@sky.position = @camera.position.clone()

			# Render the scene.
			@renderer.render(@scene, @camera)

			# Update stats.			
			@stats.update()

			# Request a new animation frame.
			@_lastUpdateTime = timestamp
			window.requestAnimationFrame(@update)

		createControllerNode: () ->
			@infoScreen.showLoadingScreen()
			@inputHandler._generateRemoteMobile()
			@inputHandler.on('mobile.initialized', ( id ) =>
					@inputHandler.selectInput('mobile')
					url = window.location.origin + "/controller/" + id

					@infoScreen.showMobileConnectScreen(url)
				)

			@inputHandler.on('mobile.connected', ( id ) =>
					@infoScreen.showInfoScreen('mobile')
					@startGame()
				)

		startGame: ( position = null ) =>
			position = position || new Three.Vector3(Math.random(), Math.random(), Math.random())
			position.normalize().multiplyScalar(@world.planet.geometry.boundingSphere.radius)
			@inputHandler.on('Boost', ( value ) =>
					@inputHandler.off('Boost')
					@infoScreen.hide()
					@createPlayer(position)
				)

		time: ( ) ->
			return @node.time()

				
	window.App = new App.Game
