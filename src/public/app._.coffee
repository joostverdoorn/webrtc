define [
	'vendor/underscore'
	], ( ) -> 
	
	# Application base class
	#

	class App

		# Constructs a new app.
		#
		constructor: ( ) ->
			_.defer @initialize

		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->