define [
		'public/scripts/helpers/mixable'
		'public/scripts/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->
		class Mouse extends Mixable
			@concern EventBindings

			constructor: ( ) ->
				@_x = 0
				@_y = 0

				@_m1 = false

				document.addEventListener('mousemove', @_mouseMove, false)

				document.addEventListener('pointerlockchange', @_pointerLockChange, false);
				document.addEventListener('mozpointerlockchange', @_pointerLockChange, false);
				document.addEventListener('webkitpointerlockchange', @_pointerLockChange, false);
				document.addEventListener('pointerlockerror', @_pointerLockError, false);
				document.addEventListener('mozpointerlockerror', @_pointerLockError, false);
				document.addEventListener('webkitpointerlockerror', @_pointerLockError, false);

				document.addEventListener('mousedown', @_mouseDown, false);
				document.addEventListener('mouseup', @_mouseUp, false);

			setLockElement: ( @_lockElement ) ->
				@lockPointer()

			_mouseUp: ( e ) =>
				@_m1 = false
				@trigger('m1', @_m1)

			_mouseDown: ( e ) =>
				@_m1 = true
				@trigger('m1', @_m1)

			_pointerLockChange: ( ) =>
				if document.webkitPointerLockElement is @_lockElement
					console.log('Pointer Lock was successful.');
				else
					console.log('Pointer Lock was lost.');
					@lockPointer()

			_pointerLockError: ( ) ->
				console.log('Unable to lock pointer. :\'(')

			lockPointer: ( ) ->
				@_lockElement.requestPointerLock = @_lockElement.requestPointerLock	||
						@_lockElement.mozRequestPointerLock							||
						@_lockElement.webkitRequestPointerLock

				@_lockElement.requestPointerLock()

			_mouseMove: ( e ) =>
				movementX = e.movementX	|| e.mozMovementX || e.webkitMovementX || 0
				movementY = e.movementY || e.mozMovementY || e.webkitMovementY || 0

				if movementX isnt @_x
					@_x = movementX
					@trigger('x', @_x)

				if movementY isnt @_y
					@_y = movementY
					@trigger('y', @_y)