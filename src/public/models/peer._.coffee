define [
	'vendor/underscore'
	'vendor/adapter'
	], ( ) ->

	# This abstract base class provides webrtc connections to masters and slaves
	#
	# Public events that can be bound:
	#
	#	peer.connected - when a connection to the peer has been established
	#	peer.disconnected - when a connection to the peer was broken 
	#	peer.closed - when a connection to the peer was deliberately closed
	#
	#	peer.channel.opened - when a channel to the peer was opened
	# 	peer.channel.closed - when a channel to the peer was closed
	#	peer.channel.errored - when an error has occured to th channel
	#
	# All subclasses MUST implement the following methods:
	#	
	#	_onRemoteDescription: ( remote, description )
	#		Is called when a remote description has been received. It will create an answer. 
	#		
	#		@param id [String] a string representing the remote peer
	#		@param description [Object] an object representing the remote session description
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
		# @param id [String] the string representing the remote peer
		#
		constructor: ( @id ) ->
			@_open = false
			@_bindings = []

			@_connection = new RTCPeerConnection(@_serverConfiguration, @_connectionConfiguration)
			
			@_connection.onicecandidate = @_onIceCandidate
			@_connection.oniceconnectionstatechange = @_onIceConnectionStateChange
			@_connection.ondatachannel = @_onDataChannel			
			
			App.server.on('peer.description.set', @_onRemoteDescription)
			App.server.on('peer.candidate.add', @_onCandidateAdd)

			@on('ping', @_onPing)
			@on('pong', @_onPong)

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

		# Triggers an event on all bindings bound to that event.
		#
		# @param event [String] the event that is called
		# @param args... [Any] any arguments to pass on to the binding
		#
		_trigger: ( event, args... ) ->
			for binding in @_bindings[event] ? []
				binding.apply(@, args) 

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
		_onPing: ( ) =>
			@emit('pong')

		# Is called when a pong is received. We call the callback function defined in 
		# ping with the amount of time that has elapsed.
		#
		_onPong: ( ) =>
			@_latency = App.time() - @_pingStart
			@_pingCallback(@_latency)
			@_pingStart = undefined

		# Is called when a local description has been added. Will send this description
		# to the remote.
		#
		# @param description [RTCSessionDescription] the local session description
		#
		_onLocalDescription: ( description ) =>
			@_connection.setLocalDescription(description)
			App.server.sendTo(@id, 'peer.description.set', description)

		# Is called when a remote description has been received. It will create an answer. 
		# This method MUST be implemented by any subclasses.
		#
		# @param id [String] a string representing the remote peer
		# @param description [Object] an object representing the remote session description
		#
		_onRemoteDescription: ( remote, description ) =>
			# Subclass: implement me!

		# Provides a callback for adding ice candidates. When a candidate is present,
		# call candidate.add on the remote to add it.
		#
		# @param event [Event] the event thrown
		#
		_onIceCandidate: ( event ) =>
			if event.candidate?
				App.server.sendTo(@id, 'peer.candidate.add', event.candidate)

		# Is called when the remote wants to add an ice candidate.
		#
		# @param id [String] the id of the remote
		# @param candidate [Object] an object representing the ice candidate
		#
		_onCandidateAdd: ( remote, candidate ) =>
			if remote is @id
				candidate = new RTCIceCandidate(candidate)
				@_connection.addIceCandidate(candidate)

		# Is called when the ice connection state changed.
		#
		# @param event [Event] the connection change event
		#
		_onIceConnectionStateChange: ( event ) =>
			connectionState = @_connection.iceConnectionState
			@_trigger("peer.#{connectionState}", @, event)

		# Is called when a data channel is added to the connection.
		#
		# @param event [Event] the data channel event
		#
		_onDataChannel: ( event ) =>
			@_addChannel(event.channel)

		# Is called when a data channel message is received.
		#
		# @param event [Event] the message event
		#
		_onChannelMessage: ( event ) =>
			data = JSON.parse(event.data)
			args = [data.name, @].concat(data.args)

			@_trigger.apply(@, args)

		# Is called when the data channel is opened.
		#
		# @param event [Event] the channel open event
		#
		_onChannelOpen: ( event ) =>
			@_open = true
			@_trigger('peer.channel.opened', @, event)

		# Is called when the data channel is closed.
		#
		# @param event [Event] the channel close event
		#
		_onChannelClose: ( event ) =>
			@_open is false
			@_trigger('peer.channel.closed', @, event)

		# Is called when the data channel has errored.
		#
		# @param event [Event] the channel open event
		#
		_onChannelError: ( event ) =>
			@_trigger('peer.channel.errorer', @, event)

		