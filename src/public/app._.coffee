requirejs.config
	shim:
		'vendor/js/bootstrap': [ 'vendor/js/jquery' ]

define [
	'models/server'
	'vendor/js/underscore'
	'vendor/js/jquery'
	'vendor/js/bootstrap'
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