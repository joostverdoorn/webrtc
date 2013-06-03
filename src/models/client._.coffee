_ = require('underscore')._
Backbone = require('backbone')

# This abstract class provides websocket connections for masters and slaves
#

class Client

	# Constructs a new client.
	#
	# @param _socket [WebSocket] the socket that represents the client
	#
	constructor: ( @_socket ) ->
		@defaults = _.extend({}, @_defaults, @defaults ? {})

		@_socket.on('ping', @onPing)
		@_socket.on('pong', @onPong)

		_.defer @initialize

	# This method is called when the constructor has finished running. It should be
	# overridden by any subclass.
	#
	initialize: ( ) ->

	# Pings the client. A callback function should be provided to do anything
	# with the ping.
	#
	# @param callback [Function] the callback to be called when a pong was received.
	#
	ping: ( callback ) ->
		@_pingStart = App.time()
		@_pingCallback = callback
		@_socket.emit('ping')	

	# Is called when a ping is received. We just emit 'pong' back to the client.
	#
	onPing: ( ) ->
		@_socket.emit('pong')

	# Is called when a pong is received. We call the callback function defined in 
	# ping with the amount of time that has elapsed.
	#
	onPong: ( ) ->
		@_latency = App.time() - @_pingStart
		@_pingCallback(@_latency, packet)
		@_pingStart = undefined


module.exports = Client