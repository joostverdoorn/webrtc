define [
	'vendor/js/underscore'
	], ->

	EventBindings =

		ClassMethods: {}

		InstanceMethods: 

			# These event bindings are modelled after the ones that Backbone.js uses. There
			# was a strong internal struggle to either use those or the ones provided by 
			# node.js's events.EventEmitter. If in the future those prove better, I have no
			# problem switching. - Joost Verdoorn

			# Binds an event to a callback.
			#
			# @param name [String] the event name to bind
			# @param callback [Function] the callback to call
			# @param context [Object] the context of the binding
			#
			on: ( name, callback, context = null ) ->
				@_events = {} unless @_events?
				@_events[name] = [] unless @_events[name]?

				event = 
					callback: callback
					context: context

				@_events[name].push(event)

				@trigger('event.bind', name)

				return @

			# Unbinds an event.
			#
			# @param name [String] the event name to unbind
			# @param callback [Function] the callback to unbind
			# @param context [Object] the context of the binding
			#
			off: ( name = null, callback = null, context = null ) ->
				@_events = {} unless @_events?
				unless name? or callback? or context?
					return @

				names = if name then [ name ] else _.keys(@_events)
				
				for name in names

					for event in @_events[name]
						if ( not callback? or callback is event.callback ) and 
								( not context? or context is event.context )
							@_events[name] = _(@_events[name]).without event

					@trigger('event.unbind', name) if @_events[name].length is 0

				return @

			# Triggers an event.
			#
			# @param name [String] the event name to trigger
			# @param args [Any*] any arguments to pass to the callback
			#
			trigger: ( name, args... ) ->
				@_events = {} unless @_events?
				for event in @_events[name] ? []
					event.callback.apply(event.context ? @, args)

				return @