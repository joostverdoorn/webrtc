#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'library/helpers/mixable'
	'library/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->
	# Easy way to let other classes without a superclass to listen to events
	class Listener extends Mixable
		@concern EventBindings
