requirejs.config
	baseUrl: '../'

	shim:
		'jquery':
			exports: '$'

		'three':
			exports: 'THREE'

		'bootstrap': [ 'jquery' ]
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
		'stats': 'vendor/scripts/stats.min'
		
require [
	'public/scripts/app._'
	'public/library/node'

	'public/scripts/models/world'
	'public/scripts/models/entity.player'
	'public/scripts/models/keyboard'

	'jquery'
	'three'
	'stats'
	], ( App, Node, World, Player, Keyboard, $, Three ) ->

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
			sky = new THREE.Mesh( new THREE.SphereGeometry( 1000, 6, 8 ), new THREE.MeshBasicMaterial( { map: THREE.ImageUtils.loadTexture( '/images/sky.jpg' ) } ) )
			sky.scale.x = -1;
			@scene.add( sky )

			@stats = new Stats()
			@stats.domElement.style.position = 'absolute'
			@stats.domElement.style.top = '0px'
			@stats.domElement.style.right = '0px'
			@container.append(@stats.domElement)

			@world = new World(@scene)
			@node = new Node()

			@node.server.on('connect', ( ) =>
				@player = new Player(@scene, @node.id, null)
				@world.addEntity(@player)
			)

			@node.on('joined', =>
				@node.broadcast('player.joined', @player.id, @player.getTransformations())
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

			broadcastInterval = setInterval( ( ) =>
				if @player?
					@node.broadcast('player.update', @player.id, @player.getTransformations())
			, 200)

			context = $(document)
			@keyHandler = new Keyboard(context, context.keydown, context.keyup)

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

		# Updates the phyics for all objects and renders the scene. Requests a new animation frame 
		# to repeat this methods.
		#
		# @param timestamp [Integer] the time that has elapsed since the first requestAnimationFrame
		#
		update: ( timestamp ) =>
			dt = (timestamp - @lastUpdateTime) / 1000     

			# If any keys are pressed, apply angular forces to the player
			@player?.boost = @keyHandler.Keys.SPACE

			if @keyHandler.Keys.A
				@player?.cannon.addAngularForce(new Three.Vector3(0, 1, 0))
			if @keyHandler.Keys.D
				@player?.cannon.addAngularForce(new Three.Vector3(0, -1, 0))
			if @keyHandler.Keys.RETURN
				projectile = @player?.cannon.fire()
				if projectile?
					@world.addEntity(projectile)
					projectile.update(dt)
					@node.broadcast('player.fired', projectile.getTransformations())

			if @keyHandler.Keys.UP
				@player?.addAngularForce(new Three.Vector3(0, 0, -2))
			if @keyHandler.Keys.DOWN
				@player?.addAngularForce(new Three.Vector3(0, 0, 2))
			if @keyHandler.Keys.LEFT
				@player?.addAngularForce(new Three.Vector3(-2, 0, 0))
			if @keyHandler.Keys.RIGHT
				@player?.addAngularForce(new Three.Vector3(2, 0, 0))

			@world.update(dt)

			# Set the camera to follow the player
			if @player?
				x = 30 * -Math.cos(@player.cannon.rotation.y)
				z = 30 * Math.sin(@player.cannon.rotation.y)

				@camera.position.lerp(@player.position.clone().add(new Three.Vector3(x, 15, z)), .02)
				@camera.lookAt(@player.position)

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
				
	window.App = new App.Game
