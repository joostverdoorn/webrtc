requirejs.config
	baseUrl: '../'

	shim:
		'jquery':
			exports: '$'

		'bootstrap': [ 'jquery' ]
		'jquery.plugins': [ 'jquery' ]

	# We want the following paths for
	# code-sharing reasons. Now it doesn't
	# matter from where we require a module.
	paths:
		'public': './'

		'jquery': 'vendor/scripts/jquery'
		'bootstrap': 'vendor/scripts/bootstrap'

require [
	'scripts/app._'
	'library/node.structured'
	'jquery'
	], ( App, Node, $ ) ->

	# Master app class
	#

	class App.Master extends App

		# This method will be called from the baseclass when it has been constructed.
		#
		initialize: ( ) ->
			@bots = []
			console.log 'INIT'

			@newNode()
			@update()

		newNode: ( ) =>
			console.log 'CREATING'

			node = new Node()

			@bots.push(node)

			if @bots.length < 10
				setTimeout(@newNode, 5000)

		update: ( timestamp ) =>
			for node in @bots
				node.broadcast('0', '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000')

			setTimeout(@update, 200)

	window.App = new App.Master
