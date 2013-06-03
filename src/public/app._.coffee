define [
	'models/server'
	'vendor/underscore'
	], ( Server ) -> 
	
	# Application base class
	#

	class App

		# Constructs a new app.
		#
		constructor: ( ) ->
			@_initTime = performance.now()

			@_server = new Server('localhost')

			_.defer @initialize

		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->

		time: ( ) ->
			return performance.now() - @_initTime