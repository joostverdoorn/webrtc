#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [], ( ) ->

	# Application base class
	#
	class App

		# Constructs a new app.
		#
		constructor: ( ) ->
			@_initTime = Date.now()
			@initialize()

		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->

		# Returns the time that has passed since the starting of the app.
		#
		time: ( ) ->
			return Date.now() - @_initTime
