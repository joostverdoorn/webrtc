define [
		'public/scripts/helpers/mixable'
		'public/scripts/helpers/mixin.eventbindings'
		'public/scripts/models/keyboard'
		'public/scripts/models/mouse'
		'public/scripts/models/remotemobile'
	], ( Mixable, EventBindings, Keyboard, Mouse, RemoteMobile ) ->
		class Controller extends Mixable
			@concern EventBindings

			_mobileAngleMax: 40
			_mouseThreshold: 10

			@functions = {
				'FlyForward': {
					keyboard: 'W'
					mouse: {
						event: 'NONE'
					}
					mobile: {
						event: 'orientationRoll'
						sign: +1
						scale: Controller.prototype._mobileAngleMax
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
						scale: Controller.prototype._mobileAngleMax
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
						scale: Controller.prototype._mobileAngleMax
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
						scale: Controller.prototype._mobileAngleMax
					}
				}
				'GunRotateCounterClockwise': {
					keyboard: 'NONE'
					mouse: {
						event: 'x'
						sign: -1
						scale: Controller.prototype._mouseThreshold
					}
					mobile: {
						event: 'cannonX'
						sign: -1
						scale: Controller.prototype._mouseThreshold
					}
				}
				'GunRotateClockwise': {
					keyboard: 'NONE'
					mouse: {
						event: 'x'
						sign: +1
						scale: Controller.prototype._mouseThreshold
					}
					mobile: {
						event: 'cannonX'
						sign: +1
						scale: Controller.prototype._mouseThreshold
					}
				}
				'GunRotateUpward': {
					keyboard: 'NONE'
					mouse: {
						event: 'y'
						sign: -1
						scale: Controller.prototype._mouseThreshold
					}
					mobile: {
						event: 'cannonY'
						sign: -1
						scale: Controller.prototype._mouseThreshold
					}
				}
				'GunRotateDownward': {
					keyboard: 'NONE'
					mouse: {
						event: 'y'
						sign: +1
						scale: Controller.prototype._mouseThreshold
					}
					mobile: {
						event: 'cannonY'
						sign: +1
						scale: Controller.prototype._mouseThreshold
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
				console.log Controller.functions
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

			_evaluateScaled: ( data, value ) =>
				if data.sign
					result = value * data.sign / data.scale
					if result > 1
						result = 1
					else if result < 0
						result = 0
				else
					if value
						result = 1
					else
						result = 0

				return result

			_triggerScaled: ( data, fn, value ) =>
				value = @_evaluateScaled(data, value)

				@trigger(fn, value)

			_getMobile: ( data ) =>
				=>
					result = @_evaluateScaled(data, @_remoteMobile["_#{data.event}"])

					if data.sign? and result > 0
						@_remoteMobile["_#{data.event}"] = 0

					return result

			_getMouse: ( data ) =>
				=>
					result = @_evaluateScaled(data, @_mouse["_#{data.event}"])

					if data.sign? and result > 0
						@_mouse["_#{data.event}"] = 0

					return result

			_triggerKeyboard: ( button, fn ) =>
				@_keyboard.on(button, ( value ) =>
						if @["get#{fn}"] is @["_get#{fn}Keyboard"]
							@trigger(fn, value)
					)

			_triggerMobile: ( data, fn ) =>
				@_remoteMobile.on(data.event, ( value ) =>
						if @["get#{fn}"] is @["_get#{fn}Mobile"]
							@_triggerScaled(data, fn, value)
					)


			_triggerMouse: ( data, fn ) =>
				@_mouse.on(data.event, ( value ) =>
						if @["get#{fn}"] is @["_get#{fn}Mouse"]
							@_triggerScaled(data, fn, value)
					)
