requirejs.config
	baseUrl: '../'

	shim:
		'jquery':
			exports: '$'

		'three':
			exports: 'THREE'

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
	'qrcode'
	'stats'
	], ( App, ControllerNode, Node, World, Player, Controller, WelcomeScreen, $, Three, QRCode ) ->

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
			@scene.add(@camera)

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

				@player?.cannon.addAngularForce(new Three.Euler(0, .6 * @inputHandler.getGunRotateCounterClockwise(), 0, 'YXZ'))
				@player?.cannon.addAngularForce(new Three.Euler(0, -.6 * @inputHandler.getGunRotateClockwise(), 0, 'YXZ'))

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
			if @player?
				# Get the player's rotation quaternion
				rotationQuaternion = new Three.Quaternion().setFromEuler(@player.rotation)

				# Get the two vectors that span the plane perpendicular to the vector 
				# that points backward from the player
				playerUpVector = @player.position.clone().normalize()
				playerZVector = new Three.Vector3(0, 0, 1).applyQuaternion(rotationQuaternion)

				# Get the target position of the camera
				targetPosition = new Three.Vector3().crossVectors(playerUpVector, playerZVector).negate().multiplyScalar(40)
				targetPosition.add(@player.position.clone()).add(@player.position.clone().normalize().multiplyScalar(40))

				# Ease the camera to the target position
				@camera.position.lerp(targetPosition, .05)

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
			###
			@controllerNode = new ControllerNode()
			@controllerNode._peers.on('controller.orientation', ( peer, orientation ) =>
				console.log orientation
			)
			@controllerNode._peers.on('controller.boost', ( peer, boost ) =>
				console.log boost
			)
			@controllerNode._peers.on('controller.orientation', ( peer, fire ) =>
				console.log fire
			)
			@welcomeScreen.showLoadingScreen()
			@controllerNode.server.on('connect', ( peer ) =>
					@controllerNode.server.off('connect')
					@welcomeScreen.showMobileConnectScreen(@setQRCode)
					@controllerNode.on('peer.added', ( peer ) =>
							@controllerNode.off('peer.added')
							@inputHandler.selectInput('mobile')
							@welcomeScreen.showInfoScreen(type)
							@startGame()
						)
				)
			###
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
