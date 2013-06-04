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
			@_connection = new RTCPeerConnection(@_serverConfiguration, @_connectionConfiguration)
			@_connection.onicecandidate = @onIceCandidate
			@_connection.ondatachannel = @onDataChannel
			
			App.server.on('description.set', @onRemoteDescription)
			App.server.on('candidate.add', @onCandidateAdd)

			@initialize()

		# This method is called from the constructor and should be overridden by subclasses
		#
		initialize: ( ) ->

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
			console.log event

		# Is called when the data channel is opened.
		#
		# @param event [Event] the channel open event
		#
		onChannelOpen: ( event ) =>
			console.log event

		# Is called when the data channel is closed.
		#
		# @param event [Event] the channel close event
		#
		onChannelClose: ( event ) =>
			console.log event

		# Is called when the data channel has errored.
		#
		# @param event [Event] the channel open event
		#
		onChannelError: ( event ) =>
			console.log event			

		ping: ( callback ) ->

		pong: ( ) ->

		onPong: ( ) ->