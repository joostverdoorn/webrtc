requirejs.config
	shim:		
		'underscore':
			expors: '_'

		'socket.io':
			exports: 'io'

		'jquery':
			exports: '$'

		'bootstrap': [ 'jquery' ]

	# We want the following paths for 
	# code-sharing reasons. Now it doesn't 
	# matter from where we require a module.
	paths:
		'public': './'

		'underscore': 'vendor/scripts/underscore'
		'jquery': 'vendor/scripts/jquery'
		'bootstrap': 'vendor/scripts/bootstrap'
		'socket.io': 'socket.io/socket.io'

require [
	'./app._'
	'./models/node.slave'
	], ( App, Node ) =>

	# Slave app class
	#

	class App.Slave extends App

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@node1 = new Node()
			@node2 = new Node()

	window.App = new App.Slave
