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

		'jquery': 'vendor/scripts/jquery'
		'bootstrap': 'vendor/scripts/bootstrap'
		'three': 'vendor/scripts/three'
		
require [
	'public/scripts/app._'
	'public/library/node'
	'public/scripts/models/world'

	'jquery'
	'three'
	], ( App, Node, World, $, Three ) ->

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
			@node = new Node()

			@container = $('#container')
		

			[width, height] = @setDimensions()
			@aspectRatio = width / height

			@renderer = new Three.WebGLRenderer({antialias: true})
			@camera = new Three.PerspectiveCamera(@viewAngle, @aspectRatio, @nearClip, @farClip)

			@scene = new Three.Scene()
			@world = new World(@scene)

			@scene.add(@camera)
			@camera.position.z = 20;
			@camera.position.y = 5
			@camera.rotation.x = -.2
			@renderer.setSize(width, height)

			@container.append(@renderer.domElement)


			window.requestAnimationFrame(@update)
			$(window).resize(@setDimensions)

		# Sets the dimensions of the container
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

		# Renders
		update: ( timestamp ) =>
			dt = timestamp - @lastUpdateTime

			@world.update(dt)
			@renderer.render(@scene, @camera)
			
			@lastUpdateTime = timestamp
			window.requestAnimationFrame(@update)

				
	window.App = new App.Game