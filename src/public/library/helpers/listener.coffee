define [
	'library/helpers/mixable'
	'library/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->
	# Easy way to let other classes without a superclass to listen to events
	class Listener extends Mixable
		@concern EventBindings
