#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [], (  ) ->

		# Mock Socket.IO library
		class IO
			constructor: ->
				@socket = {
					sessionid: '3'
				}
				@sockets = {
					on: ->
				}
			@connect: ->
				return new IO()
			on: ->
			disconnect: ->
			emit: ->
			@listen: ->
				new IO()
