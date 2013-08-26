define [
	'library/helpers/mixable'
	'library/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->

	class Listener extends Mixable
		@concern EventBindings
