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
	'public/library/node.structured'
	
	'public/scripts/models/controller._'
	'public/scripts/models/controller.desktop'
	'public/scripts/models/controller.mobile'

	'public/scripts/models/world'
	'public/scripts/models/entity.player'

	'public/scripts/views/overlay'

	'three'
	'stats'
	], ( App, Node, Controller, DesktopController, MobileController, World, Player, Overlay, Three, Stats ) ->

	# This game class implements the node structure created in the library.
	# It uses three.js for the graphics.
	#
	class App.Game extends App

		paused = true

		viewAngle = 45
		nearClip = 0.1
		farClip = 2000

		_lastUpdateTime = 0

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			# Create node and controller.
			@node = new Node()
			@controller = new Controller()

			# Create overlay screen.
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
			@container.appendChild(@renderer.domElement)

			# Create camera.
			@aspectRatio = width / height
			@camera = new Three.PerspectiveCamera(@viewAngle, @aspectRatio, @nearClip, @farClip)
			@cameraRaycaster = new Three.Raycaster()

			# Create scene.
			@scene = new Three.Scene()
			@scene.add(@camera)
			@scene.fog = new Three.FogExp2( 0xaabbff, 0.0015 );

			# Create sky dome.
			geometry = new THREE.SphereGeometry( 1500, 6, 8 )
			material = new THREE.MeshBasicMaterial(map: THREE.ImageUtils.loadTexture('/images/sky.jpg'))
			@sky = new THREE.Mesh(geometry, material) 
			@sky.scale.x = -1;
			@scene.add( @sky )

			# Create stats display.
			@stats = new Stats()
			@stats.domElement.style.position = 'absolute'
			@stats.domElement.style.top = '20px'
			@stats.domElement.style.left = '20px'
			@container.appendChild(@stats.domElement)

			# Create the world.
			@world = new World(@scene)

			# Listen to events.
			@node.server.once
				'connect': ( ) =>

			@node.on
				'joined': =>
					@node.off('joined')
					@overlay.showWelcomeScreen()
				'left': =>
					console.log 'Left the network'

			@node.onReceive
				'player.list': ( list ) =>
					@world.createPlayer(id, info) for id, info in list
				'player.joined': ( id, info ) =>
					@world.createPlayer(id, info)
				'player.left': ( id ) =>
					@world.removePlayer(id)
				'player.died': ( id ) =>
					@world.removePlayer(id)
				'player.update': ( id, info, timestamp ) =>
					@world.applyPlayerInfo(id, info, timestamp)
				'player.fire': ( id, info, timestamp ) =>
					@world.createProjectile(info, timestamp)

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
			dt = (timestamp - @_lastUpdateTime) / 1000

			# Apply input to player.
			if @player?.loaded and not @paused
				@player.fire() if @controller.Fire
				@player.boost = @controller.Boost

				@player.flyLeft = @controller.FlyLeft
				@player.flyRight = @controller.FlyRight
				@player.flyForward = @controller.FlyForward
				@player.flyBackward = @controller.FlyBackward

				@player.cannon.rotateLeft = @controller.RotateCannonLeft
				@player.cannon.rotateRight = @controller.RotateCannonRight
				@player.cannon.rotateUpward = @controller.RotateCannonUpward
				@player.cannon.rotateDownward = @controller.RotateCannonDownward

			# Update the world
			@world.update(dt, @player)

			# Set the camera to follow the player
			if @player?.loaded
				# Get the direction of the camera, and apply cannon and player rotations to it.
				cameraDirection = new Three.Vector3(-1, 0, 0)
				cameraDirection.applyQuaternion(new Three.Quaternion().setFromEuler(@player.cannon.rotation.clone()))
				cameraDirection.applyQuaternion(new Three.Quaternion().setFromEuler(@player.rotation.clone()))

				# Get the target position of the camera
				targetPosition = @player.position.clone().add(cameraDirection.multiplyScalar(80))

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
			@_lastUpdateTime = timestamp
			window.requestAnimationFrame(@update)

		# Starts the game by finding a spawnpoint and spawning the player.
		#
		# @param position [Three.Vector3] the position override to spawn the player
		#
		startGame: ( position = null ) ->
			randomRadial = ( ) =>
				Math.random() * Math.PI * 2

			sanePosition = false
			while sanePosition is false
				radius = @world.planet.mesh.geometry.boundingSphere.radius
				euler = new Three.Euler(randomRadial(), randomRadial(), randomRadial())
				quaternion = new Three.Quaternion().setFromEuler(euler)

				position = new Three.Vector3(0, radius, 0)
				position.applyQuaternion(quaternion)

				if intersect = @world.planet.getIntersect(position, 4, radius)
					position = intersect.point
					console.log intersect
					sanePosition = true

			@createPlayer(position)
			@paused = false

		# Spawns the player in the world.
		#
		# @param position [Three.Vector3] the position at which to spawn the player
		#
		createPlayer: ( position ) =>
			if @player
				return

			@player = @world.createPlayer(@node.id, true, position: position.toArray())

			broadcastInterval = setInterval( ( ) =>
				@node.broadcast('player.update', @player.id, @player.getInfo())
			, 200)

			@player.on
				'fire': ( projectile ) =>
					@node.broadcast('player.fire', @player.id, projectile.getInfo())
				'die': ( ) =>
					@_onPlayerDied(broadcastInterval)

			@node.broadcast('player.joined', @player.id, @player.getInfo())

		# Is called when a type of controller is selected. This method will
		# set up listeners for type specific controller events.
		#
		# @param type [String] the type of controller (desktop or mobile)
		#
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

			# Start the game when we receive a Boost event. This probably means
			# the controller is set up correctly.
			@controller.once('Boost', ( ) =>
				@overlay.hide()
				@startGame()
			)

		# Is called when the player dies. Will cancel timed updates that are
		# broadcasted into the network.
		#
		# @param interval [Integer] the player broadcast interval to cancel.
		#
		_onPlayerDied: ( interval ) =>
			clearInterval(interval)
			@node.broadcast('player.died', @player.id)
			@player = null

			@overlay.showPlayerDiedScreen()
			@controller.on('Boost', ( ) =>
				@overlay.hide()
				@startGame()
			)

		# Returns the current network time.
		#
		# @return [Float] the network time
		#
		time: ( ) ->
			return @node.time()

	window.App = new App.Game
