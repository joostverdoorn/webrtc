define [], (  ) ->

		# Mock Socket.IO library
		class IO
			constructor: ->
				@socket = {
					sessionid: '3'
				}
			@connect: ->
				return new IO()
			on: ->
			disconnect: ->
			emit: ->

	