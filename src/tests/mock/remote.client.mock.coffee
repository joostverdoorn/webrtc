#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [], (  ) ->

	# Mock Remote.Client class
	class global.Client
		constructor: ->
			@id = '1'
			@on = ->
			@emit = ->

	originalPrototype = Client.prototype
	spyOn(global, 'Client').andCallThrough()

	#Client.prototype = originalPrototype

