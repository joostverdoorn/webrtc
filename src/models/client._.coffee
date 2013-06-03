_ = require('underscore')._
Backbone = require('backbone')

# This abstract class provides websocket connections for masters and slaves
#

class Client
	constructor: ( @_socket, attributes, options ) ->
		@defaults = _.extend({}, @_defaults, @defaults ? {})

		@_socket.on('pong', @onPong)

		@initialize(attributes, options)

	ping: ( callback ) ->
		@_pingStart = App.time()
		@_pingCallback = callback
		@_socket.emit('ping')	

	pong: ( ) ->
		@_socket.emit('pong')

	onPong: ( ) ->
		@_latency = App.time() - @_pingStart
		@_pingCallback(@_latency, packet)
		@_pingStart = undefined


module.exports = Client