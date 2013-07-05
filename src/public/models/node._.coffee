define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'public/models/server'
	
	'underscore'
	], ( Mixable, EventBindings, Server, _ )->

	class Node extends Mixable

		@concern EventBindings

		id: null
		serverAddress: ':8080/'

		# Constructs a new app.
		#
		constructor: ( ) ->
			@server = new Server(@, @serverAddress)
			@initialize()

		# Is called when the app has been constructed. Should be overridden by
		# subclasses.
		#
		initialize: ( ) ->