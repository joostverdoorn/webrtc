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
	
	class FakeScene
		add: ->
		remove: ->

	# Application base class
	#

	class AIApp extends App
		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->
			@bots = []
			console.log 'INIT'

			@scene = new FakeScene()

			@newBot()

			window.requestAnimationFrame(@update)

		newBot: ( ) =>
			console.log 'CREATING'
			game = new GameModel(@scene)
			game.controller = new RandomController(game)
			game.on
				'joined': =>
					game.startGame()
					console.log 'spawned on', game.player.position
				'player.died': =>
					game.startGame()
			@bots.push(game)

			if @bots.length < 25
				setTimeout(@newBot, 5000)

		update: ( timestamp ) =>
			for game in @bots
				game.update(timestamp)

			window.requestAnimationFrame(@update)

	window.App = new AIApp