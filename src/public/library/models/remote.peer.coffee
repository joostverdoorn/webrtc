#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'library/models/remote._'
	'library/models/message'

	'underscore'
	'adapter'
	], ( Remote, Message, _ ) ->

	# All other p2p peers as seen from an ordinary peer
	class Remote.Peer extends Remote

		@Role:
			None: "None"
			Parent: "Parent"
			Sibling: "Sibling"
			Child: "Child"

		role: Peer.Role.None

		# Provides default server configuration for RTCPeerConnection.
		_serverConfiguration:
			iceServers: [
				url: 'stun:stun.l.google.com:19302'
				]

		# Provides default connection configuration for RTCPeerConnection. Note that
		# 'RtpDataChannels: true' is mandatory for current Chrome (27). Expermiments
		# show that 'DtlsSrtpKeyAgreement: false' is required for current Chrome to
		# allow on-the-fly adding of media streams.
		_connectionConfiguration:
			optional: [
				{ DtlsSrtpKeyAgreement: false },
				{ RtpDataChannels: true }
				]

		# Provides default channel configuration for RTCDataChannel. Note that
		# 'reliable: false' is mandatory for current Chrome (27).
		_channelConfiguration:
			reliable: false

		# Provides default sdp constraints for the exchanged offers and answers.
		_sdpConstraints:
			mandatory:
				OfferToReceiveAudio: true
				OfferToReceiveVideo: true

		_connectionTimeout: 10000

		# Initializes this class. Will attempt to connect to a remote peer through WebRTC.
		# Is called from the baseclass' constructor.
		#
		# @param id [String] the id of the peer to connect to
		# @param instantiate [Booelean] wether to instantiate the connection or wait for the remote
		#
		initialize: ( @id, instantiate = true, PeerConnection = RTCPeerConnection ) ->
			@localIceCandidates = []
			@_remoteIceCandidates = []

			@_connection = new PeerConnection(@_serverConfiguration, @_connectionConfiguration)
			@_connection.onicecandidate = @_onIceCandidate
			@_connection.oniceconnectionstatechange = @_onIceConnectionStateChange
			@_connection.ondatachannel = @_onDataChannel
			@_connection.onaddstream = @_onAddStream

			@on('connect', @_onConnect)
			@on('disconnect', @_onDisconnect)
			@on('channel.opened', @_onChannelOpened)
			@on('channel.closed', @_onChannelClosed)

			@latency = 0

			if instantiate
				@connect()

		# Attempts to connect to the remote peer. Will query the remote to
		# see if it accepts our connection, and the connection will trigger
		# an negotiationneeded event that will be caught to start the
		# negotiation process.
		#
		connect: ( ) ->
			channel = @_connection.createDataChannel('a', @_channelConfiguration)
			@_addChannel(channel)

			timer = setTimeout(=>
				@trigger('timeout')
			, @_connectionTimeout)
			@once('connected', -> clearTimeout(timer))

			@_controller.queryTo(@id, 'requestConnection', @_controller.id, ( accepted ) =>
				clearTimeout(timer)

				unless accepted
					@trigger('failed')
					return

				@_startNegotiation()
			)

		# Disconnects from the peer.
		#
		disconnect: ( ) ->
			@_channel.close()
			@_connection.close()

		# Returns wether or not this peer is connected.
		#
		# @return [Boolean] wether or not this peer is connected
		#
		isConnected: ( ) ->
			return @_connection.iceConnectionState is 'connected'

		# Returns wether or not the data channel to this peer is open
		#
		# @return [Boolean] wether or not the channel is open
		#
		isChannelOpen: ( ) ->
			return @_channel?.readyState is 'open'

		# Sends a predefined message to the remote.
		#
		# @param message [Message] the message to send
		# @private
		_send: ( message, retries = 0 ) ->
			maxRetries = 5

			unless @isChannelOpen()
				return false

			messageString = message.serialize()

			if messageString.length > 800
				@_disassemble(message)
				return undefined

			try
				@_channel.send(messageString)
				return true
			catch error
				if retries < maxRetries
					_( => result = @_send(message, retries + 1)).defer()
					return undefined
				else
					console.log 'failed to send message', message
					return false

		# Adds a new data channel, and adds event bindings to it.
		#
		# @param channel [RTCDataChannel] the channel to be added
		# @private
		_addChannel: ( channel ) ->
			@_channel = channel

			@_channel.onmessage = @_onChannelMessage
			@_channel.onopen = @_onChannelOpen
			@_channel.onclose = @_onChannelClose
			@_channel.onerror = @_onChannelError

		# Adds a video and/or audio stream to the connection. The rtc connection
		# will fire a negotiationneeded event, which in turn will call the
		# _startNegotiation method.
		#
		# @param stream [MediaStream] the stream to be added
		#
		addStream: ( stream ) ->
			@_connection.addStream(stream)
			@_startNegotiation()

		# Removes a video and/or audio stream from the connection. The rtc
		# connection will fire a negotiationneeded event, which in turn will call
		# the _startNegotiation method.
		#
		# @param stream [MediaStream] the stream to be removed
		#
		removeStream: ( stream ) ->
			@_connection.removeStream(stream)
			@_startNegotiation()

		# Ups bandwidth limit on SDP. Meant to be called during offer/answer.
		#
		# @param sdp [RTCSessionDescription] the sdp to increase the bandwidth of
		# @private
		_higherBandwidthSDP: ( sdp ) ->
			# AS stands for Application-Specific Maximum.
			# Bandwidth number is in kilobits / sec.
			# See RFC for more info: http://www.ietf.org/rfc/rfc2327.txt
			parts = sdp.split 'b=AS:30'
			replace = 'b=AS:102400' # 100 Mbps
			if parts.length > 1
				return parts[0] + replace + parts[1]
			return sdp

		# Starts the negotiation process with the remote. It does this
		# by creating an RTCSessionDescription and sending it to the remote,
		# and expects the remote's RTCSessionDescription as answer. Does the
		# same for ice candidates.
		# @private
		_startNegotiation: ( ) =>
			@_connection.createOffer( ( description ) =>
				description.sdp = @_higherBandwidthSDP(description.sdp)
				@_connection.setLocalDescription(description)

				@_controller.queryTo(@id, 'remoteDescription', @_controller.id, description, ( data ) =>
					if data? then @setRemoteDescription(data)
					else @trigger('failed')
				)

				@once('candidates.done', ( candidates ) =>
					@_controller.queryTo(@id, 'iceCandidates', @_controller.id, candidates, ( arr ) =>
						if arr? then @addIceCandidates(arr)
						else @trigger('failed')
					)
				)
			, null, @_sdpConstraints)

		# Is called when a remote description has been received. It will
		# create an answer.
		#
		# @param data [Object] a plain object representation of the RTCSessionDescription
		#
		setRemoteDescription: ( data ) ->
			description = new RTCSessionDescription(data)
			@_connection.setRemoteDescription(description)

			if @_remoteIceCandidates.length > 0
				@addIceCandidates(@_remoteIceCandidates)
				@_remoteIceCandidates = []

		# Creates an answer RTCSessionDescription to be sent to the remote, and
		# passes it on to the callback.
		#
		# @param callback [Function] the callback to call
		#
		createAnswer: ( callback ) ->
			@_connection.createAnswer( ( description ) =>
				description.sdp = @_higherBandwidthSDP(description.sdp)
				@_connection.setLocalDescription(description)

				callback(description)
			, null, @_sdpConstraints)

		# Provides a callback for adding ice candidates. When a candidate is present,
		# call candidate.add on the remote to add it.
		#
		# @param event [Event] the event thrown
		# @private
		_onIceCandidate: ( event ) =>
			if event.candidate?
				@localIceCandidates.push(event.candidate)
			else @trigger('candidates.done', @localIceCandidates)

		# Is called when the remote wants to add an ice candidate.
		#
		# @param arr [Array] an array of basic objects representing ice candidates
		#
		addIceCandidates: ( arr ) =>
			unless @_connection.remoteDescription?
				@_remoteIceCandidates = arr
				return

			for data in arr
				candidate = new RTCIceCandidate(data)
				@_connection.addIceCandidate(candidate)

		# Is called when the ice connection state changed.
		#
		# @param event [Event] the connection change event
		# @private
		_onIceConnectionStateChange: ( event ) =>
			connectionState = @_connection.iceConnectionState

			switch connectionState
				when 'connected'
					@trigger('connect', @, event)
				when 'disconnected', 'failed', 'closed'
					@trigger('disconnect', @, event)

		# Is called when a data channel is added to the connection.
		#
		# @param event [Event] the data channel event
		# @private
		_onDataChannel: ( event ) =>
			@_addChannel(event.channel)

		# Is called when an audio or video stream is added to the connection.
		#
		# @param event [Event] the stream event
		# @private
		_onAddStream: ( event ) =>
			@trigger('stream.added', event.stream)

		# Is called when a message was received on channel.
		#
		# @param messageEvent [MessageEvent] an RTC message event
		# @private
		_onChannelMessage: ( messageEvent ) =>
			message = Message.deserialize(messageEvent.data)
			@trigger('message', message)

		# Is called when the data channel is opened.
		#
		# @param event [Event] the channel open event
		# @private
		_onChannelOpen: ( event ) =>
			@trigger('channel.opened', @, event)

		# Is called when the data channel is closed.
		#
		# @param event [Event] the channel close event
		# @private
		_onChannelClose: ( event ) =>
			@trigger('channel.closed', @, event)

		# Is called when a connection has been established.
		# @private
		_onConnect: ( ) ->
			console.log "connected to node #{@id}"

		# Is called when a connection has been broken.
		# @private
		_onDisconnect: ( ) ->
			console.log "disconnected from node #{@id}"

		# Is called when the channel has opened.
		# @private
		_onChannelOpened: ( ) ->
			console.log "channel opened to node #{@id}"

		# Is called when the channel has closed.
		# @private
		_onChannelClosed: ( ) ->
			console.log "channel closed to node #{@id}"
