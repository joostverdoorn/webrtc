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

require [
	'public/scripts/app._'
	'public/scripts/app.aigame'
	], ( App, AIGame ) -> 
	
	# Application base class
	#

	class AIApp extends App
		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->
			@bots = []
			console.log 'INIT'
			for i in [0...5]
				console.log 'CREATING'
				console.log AIGame
				@bots.push(new AIGame())

	window.App = new AIApp