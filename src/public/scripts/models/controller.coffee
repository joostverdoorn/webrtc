define [
		'public/scripts/helpers/mixable'
		'public/scripts/helpers/mixin.eventbindings'
		'public/scripts/models/keyboard'
	], ( Mixable, EventBindings, Keyboard ) ->
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
				@_keyboard = new Keyboard()

				@_generateKeyboardFunctions()

			_generateKeyboardFunctions: ( ) =>
				for button, fn of Controller.functions
					@["_get#{fn}Keyboard"] = @_getKeyboard button
					@_triggerKeyboard button, fn

			selectInput: ( type ) =>
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
