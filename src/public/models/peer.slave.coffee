define [
	'models/peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent slave
	#

	class Peer.Slave extends Peer

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@on('peer.connected', @onConnected)
			@on('peer.disconnected', @onDisconnected)
			@on('peer.channel.opened', @onChannelOpened)
			@on('peer.channel.closed', @onChannelClosed)
			
		# Is called when a connection has been established.
		#
		onConnected: ( ) ->
			console.log "connected to slave #{@id}"

		# Is called when a connection has been broken.
		#
		onDisconnected: ( ) ->
			console.log "disconnected from slave #{@id}"

		# Is called when the channel has opened.
		#
		onChannelOpened: ( ) ->
			console.log "opened channel to slave #{@id}"

		# Is called when the channel has closed.
		#
		onChannelClosed: ( ) ->
			console.log "closed channel to slave #{@id}"

		# Is called when a remote description has been received. It will create an answer.
		#
		# @param id [String] a string representing the remote peer
		# @param description [Object] an object representing the remote session description
		#
		_onRemoteDescription: ( remote, description ) =>
			if remote is @id
				description = new RTCSessionDescription(description)
				@_connection.setRemoteDescription(description)
				@_connection.createAnswer(@_onLocalDescription, null, {})
