define [
	'underscore' 
	], ( _ ) ->

	# Generic EventManager class
	#

	class EventManager
		@_bindings: {}

		# Trigger an event 
		#
		# @param event [String] the event to be thrown
		# @params args [*] the arguments to pass
		#
		@trigger: ( event, args... ) ->
			binding.apply( @, args ) for binding in @_bindings[event]

		# Binds a function to an event
		#
		# @param event [String] the event to bind on
		# @param fn [Function] the function to bind to the event
		#
		@bind: ( event, fn ) ->
			unless  _( fn ).isFunction()
				throw new TypeError
			
			unless @_bindings[event]?
				@_bidings[event] = []

			return @_bindings[event].push(fn)

		# Binds a function to from event
		#
		# @param event [String] the event to bind on
		# @param fn [Function] the function to bind to the event
		#
		@unbind: ( event, fn ) ->
			return @_bindings[event] is _(@_bindings[event]).without fn

		@on: ( event, fn ) ->
			return @bind event fn

		@off: ( event, fn ) ->
			return @unbind event fn

