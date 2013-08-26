define [
	'game/scripts/helpers/mixable'
	'game/scripts/helpers/mixin.eventbindings'
	'game/scripts/helpers/mixin.dynamicproperties'
	], ( Mixable, EventBindings, DynamicProperties ) ->

	class Controller extends Mixable
		@concern EventBindings
		@concern DynamicProperties

		@Controls:
			Fire: false
			Boost: 0
			Leaderboard: false

			FlyLeft: 0
			FlyRight: 0
			FlyForward: 0
			FlyBackward: 0

			RotateCanonLeft: 0
			RotateCannonRight: 0
			RotateCannonUpward: 0
			RotateCannonDownward: 0

		constructor: ( args... ) ->
			getters = []
			setters = []
			@values = []

			for control, value of Controller.Controls
				( ( control, value ) =>
					@values[control] = value
					getters[control] = => @values[control]
					setters[control] = ( val ) =>
						@values[control] = val
						@trigger(control, val)
				) control, value

			@getter getters
			@setter setters

			@initialize?.apply(@, args)
