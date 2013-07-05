define [
	'./peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent master.
	#

	class Peer.Master extends Peer

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@on('peer.connected', @onConnected)
			@on('peer.disconnected', @onDisconnected)
			@on('peer.channel.opened', @onChannelOpened)
			@on('peer.channel.closed', @onChannelClosed)

			App.server.sendTo(@id, 'slave.add', App.id)

			@_channel = @_connection.createDataChannel('a', @_channelConfiguration)			
			@_connection.createOffer(@_onLocalDescription)

		# Is called when a connection has been established.
		#
		onConnected: ( ) ->
			console.log "connected to master #{@id}"

		# Is called when a connection has been broken.
		#
		onDisconnected: ( ) ->
			console.log "disconnected from master #{@id}"

		# Is called when the channel has opened.
		#
		onChannelOpened: ( ) ->
			console.log "opened channel to master #{@id}"

		# Is called when the channel has closed.
		#
		onChannelClosed: ( ) ->
			console.log "closed channel to master #{@id}"

		# Is called when a remote description has been received.
		#
		# @param id [String] a string representing the remote peer
		# @param description [Object] an object representing the remote session description
		#
		_onRemoteDescription: ( remote, description ) =>
			if remote is @id
				description = new RTCSessionDescription(description)
				@_connection.setRemoteDescription(description)
				@_addChannel(@_channel)
