define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'underscore'
	'adapter'

	], ( Mixable, EventBindings, _ ) ->

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

	class Peer extends Mixable

		@concern EventBindings

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
		constructor: ( @node, @id ) ->
			@_channelOpen = false
			@_isConnector = false

			@_connection = new RTCPeerConnection(@_serverConfiguration, @_connectionConfiguration)
			
			@_connection.onicecandidate = @_onIceCandidate
			@_connection.oniceconnectionstatechange = @_onIceConnectionStateChange
			@_connection.ondatachannel = @_onDataChannel

			@on('ping', @_onPing)
			@on('pong', @_onPong)

			@on('peer.connected', @_onConnected)
			@on('peer.disconnected', @_onDisconnected)
			@on('peer.channel.opened', @_onChannelOpened)
			@on('peer.channel.closed', @_onChannelClosed)

			@node.server.on('peer.description.set', @_onRemoteDescription)
			@node.server.on('peer.candidate.add', @_onCandidateAdd)

			@initialize()

		# This method is called from the constructor and should be overridden by subclasses
		#
		initialize: ( ) ->

		# Completely removes the peer.
		#
		die: ( ) ->

		#
		#
		connect: ( ) ->
			@_isConnector = true
			@node.server.sendTo(@id, 'peer.connection.request', @node.type)

			channel = @_connection.createDataChannel('a', @_channelConfiguration)	
			@_connection.createOffer(@_onLocalDescription)

			@once('peer.connected', =>	
				@_addChannel(channel)
			)

		# Disconnects the peer.
		#
		disconnect: ( ) ->
			@_connection.close()

		# Returns the connection state of the connection.
		#
		# @return [RTCIceConnectionState] the connection state
		#
		getConnectionState: ( ) ->
			return @_connection.iceConnectionState

		# Sends a message to the remote.
		#
		# @param event [String] the event to send
		# @param args... [Any] any paramters you may want to pass
		#
		emit: ( event, args... ) ->
			unless @_channelOpen
				return false
			
			data = 
				name: event
				args: args

			@_channel.send(JSON.stringify(data))

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
			@node.server.sendTo(@id, 'peer.description.set', description)

		# Is called when a remote description has been received. It will create an answer.
		#
		# @param id [String] a string representing the remote peer
		# @param description [Object] an object representing the remote session description
		#
		_onRemoteDescription: ( remote, description ) =>
			if remote is @id
				description = new RTCSessionDescription(description)
				@_connection.setRemoteDescription(description)

				unless @_isConnector
					@_connection.createAnswer(@_onLocalDescription, null, {})

		# Provides a callback for adding ice candidates. When a candidate is present,
		# call candidate.add on the remote to add it.
		#
		# @param event [Event] the event thrown
		#
		_onIceCandidate: ( event ) =>
			if event.candidate?
				@node.server.sendTo(@id, 'peer.candidate.add', event.candidate)

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
			@trigger("peer.#{connectionState}", @, event)

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
			args = [data.name].concat(data.args)

			@trigger.apply(@, args)

		# Is called when the data channel is opened.
		#
		# @param event [Event] the channel open event
		#
		_onChannelOpen: ( event ) =>
			@_channelOpen = true
			@trigger('peer.channel.opened', @, event)

		# Is called when the data channel is closed.
		#
		# @param event [Event] the channel close event
		#
		_onChannelClose: ( event ) =>
			@_channelOpen is false
			@trigger('peer.channel.closed', @, event)

		# Is called when the data channel has errored.
		#
		# @param event [Event] the channel open event
		#
		_onChannelError: ( event ) =>
			@trigger('peer.channel.errorer', @, event)

		# Is called when a connection has been established.
		#
		_onConnected: ( ) ->
			console.log "connected to node #{@id}"

		# Is called when a connection has been broken.
		#
		_onDisconnected: ( ) ->
			console.log "disconnected from node #{@id}"

		# Is called when the channel has opened.
		#
		_onChannelOpened: ( ) ->
			console.log "opened channel to node #{@id}"

		# Is called when the channel has closed.
		#
		_onChannelClosed: ( ) ->
			console.log "closed channel to node #{@id}"

		