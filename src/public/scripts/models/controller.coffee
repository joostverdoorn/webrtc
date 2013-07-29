define [
		'public/scripts/helpers/mixable'
		'public/scripts/helpers/mixin.eventbindings'
		'public/scripts/models/keyboard'
		'public/scripts/models/remotemobile'
	], ( Mixable, EventBindings, Keyboard, RemoteMobile ) ->
		class Controller extends Mixable
			@concern EventBindings

			@functions = {
				'FlyForward': {
					keyboard: 'UP'
					mobile: {
						event: 'orientationRoll'
						sign: +1
					}
				}
				'FlyLeft': {
					keyboard: 'LEFT'
					mobile: {
						event: 'orientationPitch'
						sign: -1
					}
				}
				'FlyBackward': {
					keyboard: 'DOWN'
					mobile: {
						event: 'orientationRoll'
						sign: -1
					}
				}
				'FlyRight': {
					keyboard: 'RIGHT'
					mobile: {
						event: 'orientationPitch'
						sign: +1
					}
				}
				'GunRotateCounterClockwise': {
					keyboard: 'A'
					mobile: {
						event: 'NONE'
						sign: 0
					}
				}
				'GunRotateClockwise': {
					keyboard: 'D'
					mobile: {
						event: 'NONE'
						sign: 0
					}
				}
				'Boost': {
					keyboard: 'SPACE'
					mobile: {
						event: 'boost'
					}
				}
				'Fire': {
					keyboard: 'RETURN'
					mobile: {
						event: 'fire'
					}
				}
			}

			constructor: ( ) ->
				@_inputType = null
				@_initializedTypes = {}
				@_keyboard = new Keyboard()

				@_generateKeyboardFunctions()

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
						result = @_remoteMobile["_#{data.event}"] * data.sign / 90
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

			_triggerKeyboard: ( button, fn ) =>
				@_keyboard.on(button, ( value ) =>
						if @_inputType is 'keyboard'
							@trigger(fn, value)
					)

			_triggerMobile: ( data, fn ) =>
				@_remoteMobile.on(data.event, ( value ) =>
						if @_inputType is 'mobile'
							if data.sign
								result = value * data.sign / 90
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
