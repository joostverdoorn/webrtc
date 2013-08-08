define [
	'underscore'
	], ( _ ) ->

	# These event bindings are modelled after the ones that Backbone.js uses. There
	# was a strong internal struggle to either use those or the ones provided by
	# node.js's events.EventEmitter. If in the future those prove better, I have no
	# problem switching. - Joost Verdoorn

	EventBindings =

		ClassMethods: {}

		InstanceMethods:
			
			# Binds an event to a callback.
			#
			# @overload on(name, callback, context = null)
			#	 Binds a single event.
			# 	 @param name [String] the event name to bind
			# 	 @param callback [Function] the callback to call
			# 	 @param context [Object] the context of the binding
			#
			# @overload on(bindings)
			#	 Binds multiple events.
			#	 @param bindings [Object] an object mapping event names to functions
			#
			on: ( ) ->
				if typeof arguments[0] is 'string'
					name = arguments[0]
					callback = arguments[1]
					context = arguments[2] || null

					@_events = {} unless @_events?
					@_events[name] = [] unless @_events[name]?

					event =
						callback: callback
						context: context

					@_events[name].push(event)

				else if typeof arguments[0] is 'object'
					bindings = arguments[0]

					for name, callback of bindings
						@on(name, callback)

				return @

			# Unbinds an event.
			#
			# @param name [String] the event name to unbind
			# @param callback [Function] the callback to unbind
			# @param context [Object] the context of the binding
			#
			off: ( name = null, callback = null, context = null ) ->
				@_events = {} unless @_events?

				names = if name then [ name ] else _.keys(@_events)
				for name in names
					for event in @_events[name]
						if ( not callback? or callback is event.callback ) and
								( not context? or context is event.context )
							@_events[name] = _(@_events[name]).without event

				return @

			# Binds an event, and calls the callback only once on that event.
			#
			# @overload once(name, callback, context = null)
			#	 Binds a single event.
			# 	 @param name [String] the event name to bind
			# 	 @param callback [Function] the callback to call
			# 	 @param context [Object] the context of the binding
			#
			# @overload once(bindings)
			#	 Binds a multiple events.
			# 	 @param bindings [Object] an object mapping event names to functions
			#
			once: ( ) ->
				if typeof arguments[0] is 'string'
					name = arguments[0]
					callback = arguments[1]
					context = arguments[2] || null

					fn = ( args... ) ->
						callback.apply(context, args)
						@off(name, arguments.callee, context)

					@on(name, fn, context)

				else if typeof arguments[0] is 'object'
					bindings = arguments[0]

					for name, callback of bindings
						@once(name, callback)

				return @

			# Triggers an event.
			#
			# @param name [String] the event name to trigger
			# @param args [Any*] any arguments to pass to the callback
			#
			trigger: ( name, args... ) ->
				#console.log name, args if @role? and name isnt '*'
				@_events = {} unless @_events?
				for event in @_events[name] ? []
					event.callback.apply(event.context ? @, args)

				# Trigger an event for catch-all listeners.
				unless name is '*'
					args = ['*', name].concat(args)
					@trigger.apply(@, args)

				return @