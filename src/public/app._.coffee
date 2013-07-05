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

define [
	'public/models/server'
	
	'underscore'
	'jquery'
	'bootstrap'
	], ( Server ) -> 
	
	# Application base class
	#

	class App

		id: null
		serverAddress: ':8080/'
		
		# Constructs a new app.
		#
		constructor: ( ) ->
			@_initTime = performance.now()

			@server = new Server(@serverAddress)

			@initialize()

		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->

		# Returns the time that has passed since the starting of the app.
		#
		time: ( ) ->
			return performance.now() - @_initTime