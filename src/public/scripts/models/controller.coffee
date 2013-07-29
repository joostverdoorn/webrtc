define [
		'public/scripts/helpers/mixable'
		'public/scripts/helpers/mixin.eventbindings'
		'public/scripts/models/keyboard'
		'public/scripts/models/remotemobile'
	], ( Mixable, EventBindings, Keyboard, RemoteMobile ) ->
		class Controller extends Mixable
			@concern EventBindings

			@functions = {
				'UP':		'FlyForward'
				'LEFT':		'FlyLeft'
				'DOWN':		'FlyBackward'
				'RIGHT':	'FlyRight'
				'A':		'GunRotateCounterClockwise'
				'D':		'GunRotateClockwise'
				'SPACE':	'Boost'
				'RETURN':	'Fire'
			}

			constructor: ( ) ->
				@_inputType = null
				@_initializedTypes = {}
				@_keyboard = new Keyboard()

				@_generateKeyboardFunctions()

			_generateKeyboardFunctions: ( ) =>
				for button, fn of Controller.functions
					@["_get#{fn}Keyboard"] = @_getKeyboard button
					@_triggerKeyboard button, fn

				@_initializedTypes['keyboard'] = true

			_generateRemoteMobileFunctions: ( ) =>
				for button, fn of Controller.functions
					@["_get#{fn}Keyboard"] = @_getKeyboard button
					@_triggerKeyboard button, fn

				@_initializedTypes['mobile'] = true

			_generateRemoteMobile: () =>
				@_remoteMobile = new RemoteMobile()
				@_remoteMobile.on('initialized', =>
						@trigger('initialized')
					)
				@_remoteMobile.on('connected', =>
						@trigger('connected')
						@_generateRemoteMobileFunctions()
					)

			selectInput: ( type ) =>
				unless @_initializedTypes[type]
					throw "Inputtype #{type} not initialized; impossible to select as input"

				@_inputType = type
				localType = type.charAt(0).toUpperCase() + type.slice(1)

				for key, fn of Controller.functions
					@["get#{fn}"] = @["_get#{fn}#{localType}"]

			_getKeyboard: ( button ) =>
				=>
					if @_keyboard.Keys[button]
						result = 1
					else
						result = 0

					return result

			_triggerKeyboard: ( button, fn ) =>
				@_keyboard.on(button, ( value ) =>
						if @_inputType is 'keyboard'
							@trigger(fn, value)
					)
