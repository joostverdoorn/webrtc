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
		@id = @_socket.id

		@defaults = _.extend({}, @_defaults, @defaults ? {})

		@_socket.on('ping', @onPing)
		@_socket.on('pong', @onPong)
		@_socket.on('sendTo', @onSendTo)

		@initialize()

	# This method is called when the constructor has finished running. It should be
	# overridden by any subclass.
	#
	initialize: ( ) ->

	# Emits to the client.
	#
	# @param event [String] the event to be emitted
	# @param args... [Any] the arguments to be emitted
	#
	emit: ( event, args... ) ->
		args = [event].concat(args)
		@_socket.emit.apply(@_socket, args)

	# Is called when a sendTo event is received. Will forward the event and arguments
	# to the intended receiver.
	#
	# @param receiver [String] a string representing the receiver
	# @param event [String] the event to be emitted
	# @param args... [Any] the arguments to be emitted
	#
	onSendTo: ( receiver, event, args... ) ->
		args = [event, @id].concat(args)

		client = Server.getClient(receiver)
		client?.emit.apply(client, args)

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
		@_pingCallback(@_latency)
		@_pingStart = undefined


module.exports = Client