#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
requirejs.config
	baseUrl: '../../'

	shim:
		'jquery':
			exports: '$'

		'bootstrap': [ 'jquery' ]
		'jquery.plugins': [ 'jquery' ]

	# We want the following paths for
	# code-sharing reasons. Now it doesn't
	# matter from where we require a module.
	paths:
		'library': './library'
		'game': './game'

		'jquery': 'game/vendor/scripts/jquery'
		'bootstrap': 'game/vendor/scripts/bootstrap'

require [
	'game/scripts/app._'
	'library/node.structured'
	'jquery'
	], ( App, Node, $ ) ->

	# Comparable to App.Node but with 10 nodes without any visual representation
	#
	class App.Many extends App

		# Start app and loop to create 10 nodes
		#
		initialize: ( ) ->
			@bots = []
			console.log 'INIT'

			@newNode()
			@update()

		# add a new node and if there are less than 10, schedule another one
		#
		newNode: ( ) =>
			console.log 'CREATING'

			node = new Node()

			@bots.push(node)

			if @bots.length < 10
				setTimeout(@newNode, 5000)

		# Send about 100 bytes of data 5 times a second for all nodes
		#
		update: ( timestamp ) =>
			for node in @bots
				node.broadcast('0', '0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000')

			setTimeout(@update, 200)

	window.App = new App.Many
