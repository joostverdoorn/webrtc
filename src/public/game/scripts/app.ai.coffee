requirejs.config
	baseUrl: '../../'

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
		'library': './library'
		'game': './game'

		'underscore': 'vendor/scripts/underscore'
		'jquery': 'vendor/scripts/jquery'
		'bootstrap': 'vendor/scripts/bootstrap'
		'three': 'vendor/scripts/three'
		'qrcode': 'vendor/scripts/qrcode.min'

require [
	'game/scripts/app._'
	'game/scripts/models/game'
	'game/scripts/models/controller.random'
	'three'
	], ( App, GameModel, RandomController, Three ) ->

	# App that spawns 10 randomly controlled bots into the game
	#
	class AIApp extends App

		# Start a loop that adds bots and controls them
		#
		initialize: ( ) ->
			@bots = []
			console.log 'INIT'

			@newBot()

			window.requestAnimationFrame(@update)

		# Create a new bot, if there are not yet 10, schedule another bot creation in 5 seconds
		#
		newBot: ( ) =>
			console.log 'CREATING'

			scene = new Three.Scene()
			game = new GameModel(scene)
			game.controller = new RandomController(game)
			game.on
				'joined': =>
					game.startGame()
					console.log 'spawned on', game.player.position
				'player.died': =>
					game.startGame()
			@bots.push(game)

			if @bots.length < 10
				setTimeout(@newBot, 5000)

		# Update all bots
		#
		update: ( timestamp ) =>
			for game in @bots
				game.player?.mesh?.updateMatrixWorld()
				game.update(timestamp)

			window.requestAnimationFrame(@update)

	window.App = new AIApp
