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
	'public/scripts/models/game'
	'public/scripts/models/controller.random'
	], ( App, GameModel, RandomController ) ->
	
	# Application base class
	#

	class AIApp extends App
		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->
			@bots = []
			console.log 'INIT'
			@newBot()

			window.requestAnimationFrame(@update)

		newBot: ( ) =>
			console.log 'CREATING'
			game = new GameModel()
			game.controller = new RandomController(game)
			game.on
				'joined': =>
					game.startGame()
					console.log 'spawned on', game.player
			@bots.push(game)

			if @bots.length < 5
				setTimeout(@newBot, 10000)

		update: ( timestamp ) =>
			for game in @bots
				game.update(timestamp)

			window.requestAnimationFrame(@update)

	window.App = new AIApp