#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
requirejs.config
	baseUrl: '../../'

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

		'postprocessing/EffectComposer': [ 'three' ]
		'postprocessing/RenderPass': [ 'three' ]
		'postprocessing/ShaderPass': [ 'three' ]
		'postprocessing/MaskPass': [ 'three' ]
		'shaders/CopyShader': [ 'three' ]
		'shaders/AdditiveBlendShader': [ 'three' ]
		'shaders/VignetteShader': [ 'three' ]

	# We want the following paths for
	# code-sharing reasons. Now it doesn't
	# matter from where we require a module.
	paths:
		'library': './library'
		'game': './game'

		'underscore': 'game/vendor/scripts/underscore'
		'jquery': 'game/vendor/scripts/jquery'
		'bootstrap': 'game/vendor/scripts/bootstrap'
		'three': 'game/vendor/scripts/three'
		'qrcode': 'game/vendor/scripts/qrcode.min'
		'stats': 'game/vendor/scripts/stats.min'

		'postprocessing/EffectComposer': 'game/vendor/scripts/postprocessing/EffectComposer'
		'postprocessing/RenderPass': 'game/vendor/scripts/postprocessing/RenderPass'
		'postprocessing/ShaderPass': 'game/vendor/scripts/postprocessing/ShaderPass'
		'postprocessing/MaskPass': 'game/vendor/scripts/postprocessing/MaskPass'
		'shaders/CopyShader': 'game/vendor/scripts/shaders/CopyShader'
		'shaders/AdditiveBlendShader': 'game/vendor/scripts/shaders/AdditiveBlendShader'
		'shaders/VignetteShader': 'game/vendor/scripts/shaders/VignetteShader'

require [
	'game/scripts/app._'

	'game/scripts/models/game'

	'game/scripts/models/controller.desktop'
	'game/scripts/models/controller.mobile'

	'game/scripts/views/overlay'

	'three'
	'stats'

	'postprocessing/EffectComposer'
	'postprocessing/RenderPass'
	'postprocessing/ShaderPass'
	'postprocessing/MaskPass'
	'shaders/CopyShader'
	'shaders/AdditiveBlendShader'
	'shaders/VignetteShader'

	], ( App, GameModel, DesktopController, MobileController, Overlay, Three, Stats ) ->

	# This game class implements the node structure created in the library.
	# It uses three.js for the graphics.
	#
	class App.Game extends App

		viewAngle: 80
		nearClip: 0.1
		farClip: 20000

		# This method will be called from the baseclass when it has been constructed.
		#
		initialize: ( ) ->
			# Create scene.
			@scene = new Three.Scene()
			@scene.fog = new Three.FogExp2( 0x444fff, 0.0025 )

			# Create sky dome.
			imagePrefix = "game/images/nebula-"
			directions  = ["xpos", "xneg", "ypos", "yneg", "zpos", "zneg"]
			imageSuffix = ".png"
			skyGeometry = new Three.CubeGeometry( 20000, 20000, 20000 )

			imageURLs = []
			for i in [0...6]
				imageURLs.push( imagePrefix + directions[i] + imageSuffix )

			textureCube = Three.ImageUtils.loadTextureCube( imageURLs )
			shader = Three.ShaderLib[ "cube" ]
			shader.uniforms[ "tCube" ].value = textureCube

			skyMaterial = new Three.ShaderMaterial
				fragmentShader: shader.fragmentShader
				vertexShader: 	shader.vertexShader
				uniforms: 		shader.uniforms
				side: 			Three.BackSide

			@sky = new Three.Mesh( skyGeometry, skyMaterial )
			@scene.add( @sky )

			# Create game.
			@game = new GameModel(@scene)
			@game.on
				'stats.change': ( stats ) => @overlay.setStats(stats)
				'player.died': @_onPlayerDied

			# Create overlay/
			@overlay = new Overlay()
			@overlay.on('controller.select', @_onControllerSelect)

			# Create the container and add it to the document.
			@container = document.createElement 'div'
			@container.id = 'container'
			document.body.appendChild @container

			# Get the width and height of the window.
			width = window.innerWidth
			height = window.innerHeight

			# Create renderer.
			@renderer = new Three.WebGLRenderer({antialias: true})
			@renderer.setSize(width, height)
			@renderer.shadowMapEnabled = true
			@renderer.shadowMapSoft = true
			@container.appendChild(@renderer.domElement)


			# Create camera.
			@aspectRatio = width / height
			@camera = new Three.PerspectiveCamera(@viewAngle, @aspectRatio, @nearClip, @farClip)
			@camera.position = new Three.Vector3(650, 350, 0)
			@camera.lookAt(new Three.Vector3(0, 300, 0))
			@scene.add(@camera)

			# Composing.
			# @composer = new Three.EffectComposer(@renderer)

			# renderPass = new Three.RenderPass(@scene, @camera)
			# @composer.addPass(renderPass)

			# vignettePass = new Three.ShaderPass(Three.VignetteShader)
			# vignettePass.uniforms[ "darkness" ].value = 1.2;
			# @composer.addPass(vignettePass)

			# copyPass = new Three.ShaderPass(Three.CopyShader)
			# copyPass.renderToScreen = true
			# @composer.addPass(copyPass)

			# Create stats display.
			@stats = new Stats()
			@stats.domElement.style.position = 'absolute'
			@stats.domElement.style.top = '20px'
			@stats.domElement.style.left = '20px'
			@container.appendChild(@stats.domElement)

			@game.once
				'joined': =>
					@overlay.showWelcomeScreen()

			window.requestAnimationFrame(@update)
			window.addEventListener('resize', @setDimensions)

		# Sets the dimensions of the viewport and the aspect ration of the camera.
		#
		setDimensions: ( ) =>
			width = window.innerWidth
			height = window.innerHeight

			@renderer.setSize(width, height)

			@aspectRatio = width / height
			@camera.aspect = @aspectRatio
			@camera.updateProjectionMatrix()

		# Updates the phyics for all objects and renders the scene. Requests a new animation frame
		# to repeat this methods.
		#
		# @param timestamp [Integer] the time that has elapsed since the first requestAnimationFrame
		#
		update: ( timestamp ) =>
			if not @game.player?._dead and not @paused
				if not @overlay._statsVisible and @game.controller.Leaderboard
					@overlay.showStats()
				else if @overlay._statsVisible and not @game.controller.Leaderboard
					@overlay.hide()

			dt = @game.update(timestamp)

			# Set the camera to follow the player
			if @game.player?.loaded
				@player = @game.player
				@world = @game.world
				# Get the direction of the camera, and apply cannon and player rotations to it.
				cameraDirection = new Three.Vector3(-1, 0, 0)
				cameraDirection.applyQuaternion(new Three.Quaternion().setFromEuler(@player.cannon.rotation.clone()))
				cameraDirection.applyQuaternion(new Three.Quaternion().setFromEuler(@player.rotation.clone()))

				# Get the target position of the camera
				targetPosition = @player.position.clone().add(cameraDirection.multiplyScalar(60))

				# If the distance to the target position is not too great, ease toward it.
				if targetPosition.distanceTo(@camera.position) < 200
					@camera.position.lerp(targetPosition, 1.5 * dt)

				# Else, set the position directly.
				else @camera.position = targetPosition

				# Check if the camera doesn't intersect with the planet surface. If it does,
				# move it.
				if intersect = @world.planet.getIntersect(@camera.position, 5, 100)
					if intersect.distance < 5
						@camera.position = intersect.point.add(@camera.position.setLength(5))

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
			window.requestAnimationFrame(@update)

		# Waits for the player to press BOOST and then spawn
		waitPlayerSpawn: ( ) ->
			@controller.once('Boost', ( ) =>
				@overlay.hide()
				@game.startGame()
			)

		# Is called when a type of controller is selected. This method will
		# set up listeners for type specific controller events.
		#
		# @param type [String] the type of controller (desktop or mobile)
		# @private
		_onControllerSelect: ( type ) =>
			if type is 'desktop'
				@controller = new DesktopController()
				@controller.requestPointerLock()
				@overlay.showInfoScreen('desktop')

				@controller.on
					'controller.pointerlock.lost': ( ) =>
						@paused = true
						@overlay.show()
						@overlay.display('paused')

						@controller.once('Boost', ( ) =>
							@paused = false
							@controller.requestPointerLock()
							@overlay.hide()
						)

			else if type is 'mobile'
				@controller = new MobileController()

				@controller.once
					'initialized': ( ) =>
						@overlay.showMobileConnectScreen(@controller.node.id)
					'connected': ( ) =>
						@overlay.showInfoScreen('mobile')

				@controller.on
					'disconnected': ( ) =>
						@overlay.show()
						@overlay.showMobileConnectScreen(@controller.node.id)
						@controller.once('connected', ( ) =>
							@overlay.hide()
						)
			@game.controller = @controller

			# Start the game when we receive a Boost event. This probably means
			# the controller is set up correctly.
			@waitPlayerSpawn()

		# Is called when the player dies. Will cancel timed updates that are
		# broadcasted into the network.
		#
		# @private
		_onPlayerDied: ( ) =>
			@overlay.showStats()
			@waitPlayerSpawn()

	window.App = new App.Game
