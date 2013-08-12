define [
	'public/library/helpers/mixable'
	'public/library/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->

	class Listener extends Mixable
		@concern EventBindings