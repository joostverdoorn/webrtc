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

