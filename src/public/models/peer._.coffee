define [
	'vendor/underscore'
	'vendor/adapter'
	], ( ) ->

	# This abstract base class provides webrtc connections to masters and slaves
	#

	class Peer

		# Provides default server configuration for RTCPeerConnection.
		_serverConfiguration:
			iceServers: [
				url: 'stun:stun.l.google.com:19302'
				]

		# Provides default connection configuration for RTCPeerConnection. Note that 
		# 'RtpDataChannels: true' is mandatory for current Chrome (27).
		_connectionConfiguration:
			optional: [
				{ DtlsSrtpKeyAgreement: true }, 
				{ RtpDataChannels: true } 
				]

		# Provides default channel configuration for RTCDataChannel. Note that
		# 'reliable: false' is mandatory for current Chrome (27).
		_channelConfiguration:
			reliable: false

		# Constructs a new peer. 
		#
		# @param remote [String] the string representing the remote peer
		#
		constructor: ( @remote ) ->
			@_open = false
			@_bindings = []

			@_connection = new RTCPeerConnection(@_serverConfiguration, @_connectionConfiguration)
			
			@_connection.onicecandidate = @onIceCandidate
			@_connection.ondatachannel = @onDataChannel
			
			App.server.on('description.set', @onRemoteDescription)
			App.server.on('candidate.add', @onCandidateAdd)

			@on('ping', @onPing)
			@on('pong', @onPong)

			@initialize()

		# This method is called from the constructor and should be overridden by subclasses
		#
		initialize: ( ) ->

		# Sends a message to the remote.
		#
		# @param event [String] the event to send
		# @param args... [Any] any paramters you may want to pass
		#
		emit: ( event, args... ) ->
			unless @_open
				return false
			
			data = 
				name: event
				args: args

			@_channel.send(JSON.stringify(data))

		# Binds an event to a callback.
		#
		# @param event [String] the event to bind
		# @param callback [Function] the callback to call
		#
		on: ( event, callback ) ->
			unless @_bindings[event]?
				@_bindings[event] = []

			@_bindings[event].push(callback)

		# Unbinds an event from a callback.
		#
		# @param event [String] the event the unbind from
		# @param callback [Function] the callback to unbind
		#
		off: ( event, callback ) ->
			@_bindings[event] = _(@_bindings[event]).without callback

		# Adds a new data channel, and adds event bindings to it.
		#
		# @param channel [RTCDataChannel] the channel to be added
		#
		_addChannel: ( channel ) ->
			@_channel = channel

			@_channel.onmessage = @onChannelMessage
			@_channel.onopen = @onChannelOpen
			@_channel.onclose = @onChannelClose
			@_channel.onerror = @onChannelError

		# Provides a callback for adding ice candidates. When a candidate is present,
		# call candidate.add on the remote to add it.
		#
		# @param event [Event] the event thrown
		#
		onIceCandidate: ( event ) =>
			if event.candidate?
				App.server.sendTo(@remote, 'candidate.add', event.candidate)

		# Is called when the remote wants to add an ice candidate.
		#
		# @param remote [String] the id of the remote
		# @param candidate [Object] an object representing the ice candidate
		#
		onCandidateAdd: ( remote, candidate ) =>
			if remote is @remote
				candidate = new RTCIceCandidate(candidate)
				@_connection.addIceCandidate(candidate)

		# Is called when a data channel is added to the connection.
		#
		# @param event [Event] the data channel event
		#
		onDataChannel: ( event ) =>
			@_addChannel(event.channel)

		# Is called when a data channel message is received.
		#
		# @param event [Event] the message event
		#
		onChannelMessage: ( event ) =>
			data = JSON.parse(event.data)
			args = [data.name].concat(data.args)

			for binding in @_bindings[data.name]
				binding.apply(@, args) 

		# Is called when the data channel is opened.
		#
		# @param event [Event] the channel open event
		#
		onChannelOpen: ( event ) =>
			@_open = true
			console.log 'opened connection to peer'

		# Is called when the data channel is closed.
		#
		# @param event [Event] the channel close event
		#
		onChannelClose: ( event ) =>
			@_open is false
			console.log 'closed connection to peer'

		# Is called when the data channel has errored.
		#
		# @param event [Event] the channel open event
		#
		onChannelError: ( event ) =>
			console.log event	

		# Pings the peer. A callback function should be provided to do anything
		# with the ping.
		#
		# @param callback [Function] the callback to be called when a pong was received.
		#
		ping: ( callback ) ->
			@_pingStart = App.time()
			@_pingCallback = callback
			@emit('ping')

		# Is called when a ping is received. We just emit 'pong' back to the peer.
		#
		onPing: ( ) =>
			@emit('pong')

		# Is called when a pong is received. We call the callback function defined in 
		# ping with the amount of time that has elapsed.
		#
		onPong: ( ) =>
			@_latency = App.time() - @_pingStart
			@_pingCallback(@_latency)
			@_pingStart = undefined