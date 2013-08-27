#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'game/scripts/models/controller._'

	'underscore'
	], ( Controller, _ ) ->

	# Implementation for a controller with the use of Mouse and Keyboard
	class Controller.Desktop extends Controller

		@Keys:
			BACKSPACE:		8
			TAB:			9
			RETURN:			13
			SHIFT:			16
			CONTROL:		17
			PAUSE:			19
			CAPSLOCK:		20
			ESCAPE:			27
			SPACE:			32
			PAGEUP:			33
			PAGEDOWN:		34
			END:			35
			HOME:			36
			LEFT:			37
			UP:				38
			RIGHT:			39
			DOWN:			40
			INSERT:			45
			DELETE:			46
			NUMLOCK:		144
			NUM_MULTIPLY:	106
			NUM_PLUS:		107
			NUM_ENTER:		108
			NUM_MINUS:		109
			NUM_DECIMAL:	110
			NUM_DIVIDE:		111

		_chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
		@Keys[char] = _chars.charCodeAt(i) for i, char of _chars

		_mouseMoveScale: 1/40
		_mouseStopDelay: 50

		# Sets the appropriate setters for the Controller making sure the values are correct for keyboard/mouse use
		#
		initialize: ( ) ->
			# Key events.
			document.addEventListener('keydown', @_onKeyEvent)
			document.addEventListener('keyup', @_onKeyEvent)

			# Mouse events.
			document.addEventListener('mousedown', @_onMouseEvent, false)
			document.addEventListener('mouseup',  @_onMouseEvent, false)
			document.addEventListener('mousemove',  @_onMouseEvent, false)

			# Cross browser pointer lock events.
			document.addEventListener('pointerlockchange', @_onPointerLockChange, false)
			document.addEventListener('mozpointerlockchange', @_onPointerLockChange, false)
			document.addEventListener('webkitpointerlockchange', @_onPointerLockChange, false)
			document.addEventListener('pointerlockerror', @_onPointerLockError, false)
			document.addEventListener('mozpointerlockerror', @_onPointerLockError, false)
			document.addEventListener('webkitpointerlockerror', @_onPointerLockError, false)

			@on
				'A': ( pressed ) => @FlyLeft = pressed ? 1 : 0
				'D': ( pressed ) => @FlyRight = pressed ? 1 : 0
				'W': ( pressed ) => @FlyForward = pressed ? 1 : 0
				'S': ( pressed ) => @FlyBackward = pressed ? 1 : 0
				'SPACE': ( pressed ) => @Boost = pressed ? 1 : 0
				'MOUSE': ( pressed ) => @Fire = pressed
				'Q': ( pressed ) => @Leaderboard = pressed
				'MOUSEMOVE': ( dx, dy ) =>
					@RotateCannonLeft = if dx < 0 then -dx * @_mouseMoveScale else 0
					@RotateCannonRight = if dx > 0 then dx * @_mouseMoveScale else 0
					@RotateCannonUpward = if dy < 0 then -dy * @_mouseMoveScale else 0
					@RotateCannonDownward = if dy > 0 then dy * @_mouseMoveScale else 0

		# Requests a pointer lock from the browser.
		#
		requestPointerLock: ( ) ->
			App.container.requestPointerLock = App.container.requestPointerLock ||
				App.container.mozRequestPointerLock || App.container.webkitRequestPointerLock

			App.container.requestPointerLock()

		# Is called when a key event is fired by the browser. This will trigger a key
		# specific event.
		#
		# @param e [Event] the event fired
		# @private
		_onKeyEvent: ( e ) =>
			 key = _(Controller.Desktop.Keys).invert()[e.keyCode]
			 @trigger(key, e.type is 'keydown') if key?

		# Is called when a mouse event if fired by the browser. This will trigger
		# a specific event for different mouse events.
		#
		# @param e [Event] the event fired
		# @private
		_onMouseEvent: ( e ) =>
			if e.type in ['mousedown', 'mouseup']
				@trigger('MOUSE', e.type is 'mousedown')

			else if e.type is 'mousemove'
				dx = e.movementX || e.mozMovementX || e.webkitMovementX || 0
				dy = e.movementY || e.mozMovementY || e.webkitMovementY || 0
				@trigger('MOUSEMOVE', dx, dy)

				# Trigger a mousemove with 0 dx and 0 dy after a fixed timeout
				# to signal that the mouse has stopped moving.
				clearTimeout(@_mouseStopTimeout)
				@_mouseStopTimeout = setTimeout( =>
					@trigger('MOUSEMOVE', 0, 0)
				, @_mouseStopDelay)

		# Is called when the pointer lock changes. Determines wether we still
		# have pointer lock or not and fire the appropriate events.
		#
		# @param e [Event] the event fired
		# @private
		_onPointerLockChange: ( e ) =>
			if document.pointerLockElement is App.container ||
					document.mozPointerLockElement is App.container ||
					document.webkitPointerLockElement is App.container
				@trigger('controller.pointerlock.gained', e)
				console.log 'controller.pointerlock.gained'
			else
				@trigger('controller.pointerlock.lost', e)
				console.log 'controller.pointerlock.lost'

		# Is called when the pointer lock errors. Will fire a pointer lock error
		# event.
		#
		# @param e [Event] the event fired
		# @private
		_onPointerLockError: ( e ) =>
			console.log 'error', e
			@trigger('controller.pointerlock.error', e)
