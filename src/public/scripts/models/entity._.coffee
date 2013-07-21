define [ 
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'

	'three'
	], ( Mixable, EventBindings, Three ) ->

	# Baseclass for all physics entities
	#
	class Entity extends Mixable
		@concern EventBindings

		constructor: ( callback = null ) ->
			@_loader = new Three.JSONLoader()	
			@initialize?(callback)

		update: ( dt ) ->

