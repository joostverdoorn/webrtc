# requirejs.config
# 	shim:		
# 		'underscore':
# 			exports: '_'

# 		'socket.io':
# 			exports: 'io'

# 		'jquery':
# 			exports: '$'

# 		'bootstrap': [ 'jquery' ]
# 		'public/vendor/scripts/jquery.plugins': [ 'jquery' ]

# 	# We want the following paths for 
# 	# code-sharing reasons. Now it doesn't 
# 	# matter from where we require a module.
# 	paths:
# 		'public': './'

# 		'underscore': 'vendor/scripts/underscore'
# 		'jquery': 'vendor/scripts/jquery'
# 		'bootstrap': 'vendor/scripts/bootstrap'
# 		'adapter' : 'vendor/scripts/adapter'
# 		'socket.io': 'socket.io/socket.io'

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