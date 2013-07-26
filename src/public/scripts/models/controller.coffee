define [
		'public/scripts/models/keyboard'
	], ( Keyboard ) ->
		class Controller

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

			selectInput: ( type ) =>
				@_inputType = type
				localType = type.charAt(0).toUpperCase() + type.slice(1)

				for key, fn of Controller.functions
					@["get#{fn}"] = @["_get#{fn}#{localType}"]

			_getKeyboard: ( button ) =>
				=>
					if @_keyboard.Keys[button]
						return 1
					else
						return 0