define [
	'public/library/models/remote._'
	'public/library/models/vector'

	'underscore'
	'adapter'
	], ( Remote, Vector, _ ) ->

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

		_connectionTimeout: 10000
		_iceCandidateGenerationTimeout: 1000

		# Initializes this class. Will attempt to connect to a remote peer through WebRTC.
		# Is called from the baseclass' constructor.
		#
		# @param id [String] the id of the peer to connect to
		# @param instantiate [Booelean] wether to instantiate the connection or wait for the remote
		#
		initialize: ( @id, instantiate = true, WebRTCObject = RTCPeerConnection ) ->
			@iceCandidates = []

			@_connection = new WebRTCObject(@_serverConfiguration, @_connectionConfiguration)
			@_connection.onicecandidate = @_onIceCandidate
			@_connection.oniceconnectionstatechange = @_onIceConnectionStateChange
			@_connection.ondatachannel = @_onDataChannel

			@on('connect', @_onConnect)
			@on('disconnect', @_onDisconnect)
			@on('channel.opened', @_onChannelOpened)
			@on('channel.closed', @_onChannelClosed)

			@latency = 0

			if instantiate
				@connect()

		# Attempts to connect to the remote peer.
		#
		connect: ( ) ->
			@_isConnector = true

			channel = @_connection.createDataChannel('a', @_channelConfiguration)
			@_addChannel(channel)

			timer = setTimeout( ( ) =>
				@trigger('timeout')
			, @_connectionTimeout )

			@_controller.queryTo(@id, 'requestConnection', @_controller.id, ( accepted ) =>
				unless accepted
					console.log 'connection request denied'
					@trigger('failed')
					clearTimeout(timer)
					return

				@_connection.createOffer( ( description ) =>
					@_setLocalDescription(description, ( description ) =>
						@_controller.queryTo(@id, 'remoteDescription', @_controller.id, description, ( data ) =>
							if data? then @setRemoteDescription(data)
						)
					)
				)
			)

			@once('channel.opened', ( ) => clearTimeout(timer))

		# Disconnects from the peer.
		#
		disconnect: ( ) ->
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
		#
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
		#
		_addChannel: ( channel ) ->
			@_channel = channel

			@_channel.onmessage = @_onChannelMessage
			@_channel.onopen = @_onChannelOpen
			@_channel.onclose = @_onChannelClose
			@_channel.onerror = @_onChannelError

		# Ups bandwidth limit on SDP. Meant to be called during offer/answer.
		_higherBandwidthSDP: ( sdp ) ->
			# AS stands for Application-Specific Maximum.
			# Bandwidth number is in kilobits / sec.
			# See RFC for more info: http://www.ietf.org/rfc/rfc2327.txt
			parts = sdp.split 'b=AS:30'
			replace = 'b=AS:102400' # 100 Mbps
			if parts.length > 1
				return parts[0] + replace + parts[1]
			return sdp

		# Is called when a local description has been added. Will send this description
		# to the remote.
		#
		# @param description [RTCSessionDescription] the local session description
		#
		_setLocalDescription: ( description, callback ) =>
			description.sdp = @_higherBandwidthSDP(description.sdp)
			@_connection.setLocalDescription(description)
			callback?(description)

		# Is called when a remote description has been received. It will create an answer.
		#
		# @param id [String] a string representing the remote peer
		# @param description [Object] an object representing the remote session description
		#
		setRemoteDescription: ( data, callback ) =>
			description = new RTCSessionDescription(data)
			@_connection.setRemoteDescription(description)

			if @_isConnector
				setTimeout( ( ) =>
					@_controller.queryTo(@id, 'iceCandidates', @_controller.id, @iceCandidates, ( arr ) =>
						if arr? then @addIceCandidates(arr)
					)
				, @_iceCandidateGenerationTimeout)
			else
				@_connection.createAnswer( ( description ) =>
					@_setLocalDescription(description, callback)
				, null, {})

		# Provides a callback for adding ice candidates. When a candidate is present,
		# call candidate.add on the remote to add it.
		#
		# @param event [Event] the event thrown
		#
		_onIceCandidate: ( event ) =>
			if event.candidate?
				@iceCandidates.push(event.candidate)

		# Is called when the remote wants to add an ice candidate.
		#
		# @param id [String] the id of the remote
		# @param candidate [Object] an object representing the ice candidate
		#
		addIceCandidates: ( arr ) =>
			for data in arr
				candidate = new RTCIceCandidate(data)
				console.log candidate
				@_connection.addIceCandidate(candidate)

		# Is called when the ice connection state changed.
		#
		# @param event [Event] the connection change event
		#
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
		#
		_onDataChannel: ( event ) =>
			@_addChannel(event.channel)

		# Is called when a message was received on channel.
		#
		# @param messageEvent [MessageEvent] an RTC message event
		#
		_onChannelMessage: ( messageEvent ) =>
			@trigger('message', messageEvent.data)

		# Is called when the data channel is opened.
		#
		# @param event [Event] the channel open event
		#
		_onChannelOpen: ( event ) =>
			@trigger('channel.opened', @, event)

		# Is called when the data channel is closed.
		#
		# @param event [Event] the channel close event
		#
		_onChannelClose: ( event ) =>
			@trigger('channel.closed', @, event)

		# Is called when a connection has been established.
		#
		_onConnect: ( ) ->
			console.log "connected to node #{@id}"

		# Is called when a connection has been broken.
		#
		_onDisconnect: ( ) ->
			console.log "disconnected from node #{@id}"

		# Is called when the channel has opened.
		#
		_onChannelOpened: ( ) ->
			console.log "channel opened to node #{@id}"

		# Is called when the channel has closed.
		#
		_onChannelClosed: ( ) ->
			console.log "channel closed to node #{@id}"