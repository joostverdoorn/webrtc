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

	'public/views/welcomeScreen'

	'jquery'
	'three'
	'stats'
	'qrcode'
	], ( App, ControllerNode, Node, World, Player, Controller, WelcomeScreen, $, Three, Stats, QRCode ) ->

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
			@welcomeScreen = new WelcomeScreen $('#overlay'), false
			@welcomeScreen.on('controllerType', ( type ) =>
					switch type
						when 'mouse'
							@inputHandler.selectInput(type)
							@welcomeScreen.showInfoScreen('keyboard')

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
			@container.append(@renderer.domElement)

			@aspectRatio = width / height
			@camera = new Three.PerspectiveCamera(@viewAngle, @aspectRatio, @nearClip, @farClip)
			@camera.position.x = -30
			@camera.position.z = 0
			@camera.position.y = 0
			@camera.rotation.y = -1 * Math.PI / 2
			@cameraRaycaster = new Three.Raycaster()

			@scene.add(@camera)
			@scene.fog = new Three.FogExp2( 0xaabbff, 0.0012 );

			@lastUpdateTime = 0

			# Create sky dome
			@sky = new THREE.Mesh( new THREE.SphereGeometry( 1000, 6, 8 ), new THREE.MeshBasicMaterial( { map: THREE.ImageUtils.loadTexture( '/images/sky.jpg' ) } ) )
			@sky.scale.x = -1;
			@scene.add( @sky )

			@stats = new Stats()
			@stats.domElement.style.position = 'absolute'
			@stats.domElement.style.top = '100px'
			@stats.domElement.style.right = '0px'
			@container.append(@stats.domElement)

			@world = new World(@scene)
			@node = new Node()

			@status = 0

			@node.server.on('connect', ( ) =>
				# now ready to spawn player
				@node.server.off('connect')
				@status = 1
			)

			@node.on('joined', =>
				# now ready to broadcast player
				@node.off('joined')
				@welcomeScreen.showWelcomeScreen()
				@status = 2
			)

			@node.on('left', =>
				console.log 'Left the network'
			)

			@node.onReceive('player.list', ( list ) =>
				@world.addPlayer(id, transformations) for id, transformations in list
			)

			@node.onReceive('player.joined', ( id, transformations ) =>
				@world.addPlayer(id, transformations)
			)

			@node.onReceive('player.left', ( id ) =>
				@world.removePlayer(id)
			)

			@node.onReceive('player.update', (id, transformations ) =>
				@world.updatePlayer(id, transformations)
			)

			@node.onReceive('player.fired', ( projectileTransformations ) =>
				@world.drawProjectiles(projectileTransformations)
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

		spawnPlayer: ( @allowInput = true, @applyGravity = true ) =>
			if @player
				return

			if @status >= 2
				@player = new Player(@scene, @node.id, {position: new Three.Vector3(0, 300, 0).toArray()})
				@player.applyGravity = @applyGravity
				@world.addEntity(@player)

				@node.broadcast('player.joined', @player.id, @player.getTransformations())

				broadcastInterval = setInterval( ( ) =>
					if @player?
						@node.broadcast('player.update', @player.id, @player.getTransformations())
				, 200)

		# Updates the phyics for all objects and renders the scene. Requests a new animation frame 
		# to repeat this methods.
		#
		# @param timestamp [Integer] the time that has elapsed since the first requestAnimationFrame
		#
		update: ( timestamp ) =>
			dt = (timestamp - @lastUpdateTime) / 1000     

			if @player?.cannon? and @allowInput
				# If any keys are pressed, apply angular forces to the player
				@player?.boost = @inputHandler.getBoost()

				@player?.cannon.addAngularForce(new Three.Euler(0, .4 * @inputHandler.getGunRotateCounterClockwise(), 0, 'YXZ'))
				@player?.cannon.addAngularForce(new Three.Euler(0, -.4 * @inputHandler.getGunRotateClockwise(), 0, 'YXZ'))
				@player?.cannon.addAngularForce(new Three.Euler(0, 0, .4 * @inputHandler.getGunRotateUpward(), 'YXZ'))
				@player?.cannon.addAngularForce(new Three.Euler(0, 0, -.4 * @inputHandler.getGunRotateDownward(), 'YXZ'))

				if @inputHandler.getFire()
					projectile = @player?.cannon.fire()
					if projectile?
						@world.addEntity(projectile)
						projectile.update(dt)
						@node.broadcast('player.fired', projectile.getTransformations())

				@player?.addAngularForce(new Three.Euler(0, 0, -.6 * @inputHandler.getFlyForward(), 'YXZ'))
				@player?.addAngularForce(new Three.Euler(0, 0, .6 * @inputHandler.getFlyBackward(), 'YXZ'))
				@player?.addAngularForce(new Three.Euler(-.6 * @inputHandler.getFlyLeft(), 0, 0, 'YXZ'))
				@player?.addAngularForce(new Three.Euler(.6 * @inputHandler.getFlyRight(), 0, 0, 'YXZ'))

			@world.update(dt)

			# Set the camera to follow the player
			if @player? and @player.cannon?
				# Get the direction of the camera, and apply cannon and player rotations to it.
				cameraDirection = new Three.Vector3(-1, 0, 0)
				cameraDirection.applyQuaternion(new Three.Quaternion().setFromEuler(@player.cannon.rotation.clone()))
				cameraDirection.applyQuaternion(new Three.Quaternion().setFromEuler(@player.rotation.clone()))

				# Get the target position of the camera
				targetPosition = @player.position.clone().add(cameraDirection.multiplyScalar(80))

				currentLength = targetPosition.length()
				planetRadius = @world.planet.geometry.boundingSphere.radius + 20
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

			# Render the scene
			@renderer.render(@scene, @camera)

			# Update the location statistics
			$('#stats .x').html(@player?.position.x)
			$('#stats .y').html(@player?.position.y)
			$('#stats .z').html(@player?.position.z)
			$('#stats .velocity').html(@player?.velocity.length())
			
			@stats.update()

			# Request a new animation frame
			@lastUpdateTime = timestamp
			window.requestAnimationFrame(@update)

		createControllerNode: () ->
			@welcomeScreen.showLoadingScreen()
			@inputHandler._generateRemoteMobile()
			@inputHandler.on('mobile.initialized', ( id ) =>
					@_controllerID = id
					@inputHandler.selectInput('mobile')
					@welcomeScreen.showMobileConnectScreen(@setQRCode)
				)

			@inputHandler.on('mobile.connected', ( id ) =>
					@welcomeScreen.showInfoScreen('mobile')
					@startGame()
				)

		startGame: () =>
			@inputHandler.on('Boost', ( value ) =>
					@inputHandler.off('Boost')
					@welcomeScreen.hide()
					@spawnPlayer(true, true)
				)

		setQRCode: () =>
			link = window.location.origin + "/controller/" + @_controllerID
			$('#controllerQRCodeImage').qrcode(link)
			$('#controllerQRCodeLink').html("<a href=\"#{link}\">#{link}</a>")

				
	window.App = new App.Game
