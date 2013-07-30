define [
		'public/scripts/helpers/mixable'
		'public/scripts/helpers/mixin.eventbindings'
		'public/scripts/models/keyboard'
		'public/scripts/models/mouse'
		'public/scripts/models/remotemobile'
	], ( Mixable, EventBindings, Keyboard, Mouse, RemoteMobile ) ->
		class Controller extends Mixable
			@concern EventBindings

			_mobileThreshold: 40
			_mouseThreshold: 2

			@functions = {
				'FlyForward': {
					keyboard: 'W'
					mouse: {
						event: 'NONE'
					}
					mobile: {
						event: 'orientationRoll'
						sign: +1
					}
				}
				'FlyLeft': {
					keyboard: 'A'
					mouse: {
						event: 'NONE'
					}
					mobile: {
						event: 'orientationPitch'
						sign: -1
					}
				}
				'FlyBackward': {
					keyboard: 'S'
					mouse: {
						event: 'NONE'
					}
					mobile: {
						event: 'orientationRoll'
						sign: -1
					}
				}
				'FlyRight': {
					keyboard: 'D'
					mouse: {
						event: 'NONE'
					}
					mobile: {
						event: 'orientationPitch'
						sign: +1
					}
				}
				'GunRotateCounterClockwise': {
					keyboard: 'NONE'
					mouse: {
						event: 'x'
						sign: -1
					}
					mobile: {
						event: 'NONE'
						sign: 0
					}
				}
				'GunRotateClockwise': {
					keyboard: 'NONE'
					mouse: {
						event: 'x'
						sign: +1
					}
					mobile: {
						event: 'NONE'
						sign: 0
					}
				}
				'GunRotateUpward': {
					keyboard: 'NONE'
					mouse: {
						event: 'y'
						sign: -1
					}
					mobile: {
						event: 'NONE'
						sign: 0
					}
				}
				'GunRotateDownward': {
					keyboard: 'NONE'
					mouse: {
						event: 'y'
						sign: +1
					}
					mobile: {
						event: 'NONE'
						sign: 0
					}
				}
				'Boost': {
					keyboard: 'SPACE'
					mouse: {
						event: 'NONE'
					}
					mobile: {
						event: 'boost'
					}
				}
				'Fire': {
					keyboard: 'RETURN'
					mouse: {
						event: 'm1'
					}
					mobile: {
						event: 'fire'
					}
				}
			}

			constructor: ( ) ->
				@_inputType = null
				@_initializedTypes = {}
				@_keyboard = new Keyboard()

				@_mouse = new Mouse(document.getElementById('container'))

				@_generateKeyboardFunctions()
				@_generateMouseFunctions()

			_generateKeyboardFunctions: ( ) =>
				for fn, button of Controller.functions
					unless button.keyboard
						return

					button = button.keyboard
					@["_get#{fn}Keyboard"] = @_getKeyboard button
					@_triggerKeyboard button, fn

				@_initializedTypes['keyboard'] = true

			_generateRemoteMobileFunctions: ( ) =>
				for fn, data of Controller.functions
					unless data.mobile
						continue

					data = data.mobile
					@["_get#{fn}Mobile"] = @_getMobile data
					@_triggerMobile data, fn

				@_initializedTypes['mobile'] = true

			_generateMouseFunctions: ( ) =>
				for fn, data of Controller.functions
					unless data.mouse
						continue

					data = data.mouse

					if data.event is 'NONE'
						@["_get#{fn}Mouse"] = @["_get#{fn}Keyboard"]
						continue

					@["_get#{fn}Mouse"] = @_getMouse data
					@_triggerMouse data, fn

				@_initializedTypes['mouse'] = true

			_generateRemoteMobile: () =>
				@_remoteMobile = new RemoteMobile()
				@_generateRemoteMobileFunctions()
				@_remoteMobile.on('initialized', ( id ) =>
						@trigger('mobile.initialized', id)
					)
				@_remoteMobile.on('connected', =>
						@trigger('mobile.connected')
					)

			selectInput: ( type ) =>
				unless @_initializedTypes[type]
					throw "Inputtype #{type} not initialized; impossible to select as input"

				if type is 'mouse'
					@_mouse.setLockElement(document.getElementById('container'))

				@_inputType = type
				localType = type.charAt(0).toUpperCase() + type.slice(1)

				for fn, key of Controller.functions
					@["get#{fn}"] = @["_get#{fn}#{localType}"]

			_getKeyboard: ( button ) =>
				=>
					if @_keyboard.Keys[button]
						result = 1
					else
						result = 0

					return result

			_getMobile: ( data ) =>
				=>
					if data.sign
						result = @_remoteMobile["_#{data.event}"] * data.sign / @_mobileThreshold
						if result > 1
							result = 1
						else if result < 0
							result = 0
					else
						if @_remoteMobile["_#{data.event}"]
							result = 1
						else
							result = 0

					return result

			_getMouse: ( data ) =>
				=>
					if data.sign
						result = @_mouse["_#{data.event}"] * data.sign / @_mouseThreshold
						if result > 1
							result = 1
						else if result < 0
							result = 0
					else
						if @_mouse["_#{data.event}"]
							result = 1
						else
							result = 0

					if data.sign? and result > 0
						@_mouse["_#{data.event}"] = 0

					return result

			_triggerKeyboard: ( button, fn ) =>
				@_keyboard.on(button, ( value ) =>
						#if @_inputType is 'keyboard'
							@trigger(fn, value)
					)

			_triggerMobile: ( data, fn ) =>
				@_remoteMobile.on(data.event, ( value ) =>
						if @_inputType is 'mobile'
							if data.sign
								result = value * data.sign / @_mobileThreshold
								if result > 1
									result = 1
								else if result < 0
									result = 0
									return
							else
								if value
									value = 1
								else
									value = 0

							@trigger(fn, value)
					)


			_triggerMouse: ( data, fn ) =>
				@_mouse.on(data.event, ( value ) =>
						if @_inputType is 'mouse'
							if data.sign
								result = value * data.sign / @_mouseThreshold
								if result > 1
									result = 1
								else if result < 0
									result = 0
									return
							else
								if value
									value = 1
								else
									value = 0

							@trigger(fn, value)
					)
