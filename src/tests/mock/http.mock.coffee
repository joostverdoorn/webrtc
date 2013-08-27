#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [], (  ) ->
	# Mock HTTP library
	class HTTP
		constructor: ->
		@createServer: ->
			return new HTTP()
		listen: jasmine.createSpy('listen')

