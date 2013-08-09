define [], (  ) ->
	# Mock HTTP library
	class HTTP
		constructor: ->
		@createServer: ->
			return new HTTP()
		listen: jasmine.createSpy('listen')

