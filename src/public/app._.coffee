define [], ( ) -> 
	
	# Application base class
	#

	class App
		
		# Constructs a new app.
		#
		constructor: ( ) ->
			@_initTime = performance.now()
			@initialize()

		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->

		# Returns the time that has passed since the starting of the app.
		#
		time: ( ) ->
			return performance.now() - @_initTime