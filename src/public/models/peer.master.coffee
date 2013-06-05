define [
	'./peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent slave
	#

	class Peer.Master extends Peer

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			App.server.sendTo(@id, 'slave.add', App.id)

			@on('channel.open', @onChannelOpen)
			@on('channel.close', @onChannelClose)

			channel = @_connection.createDataChannel('a', @_channelConfiguration)
			@_addChannel(channel)
			
			@_connection.createOffer(@_onLocalDescription)

		# Is called when the channel has opened.
		#
		onChannelOpen: ( ) ->
			console.log 'opened channel to master'

		# Is called when the channel has closed.
		#
		onChannelClose: ( ) ->
			console.log 'closed channel to master'

		# Is called when a local description has been added. Will send this description
		# to the remote.
		#
		# @param description [RTCSessionDescription] the local session description
		#
		_onLocalDescription: ( description ) =>
			@_connection.setLocalDescription(description)
			App.server.sendTo(@id, 'description.set', description)

		# Is called when a remote description has been received.
		#
		# @param id [String] a string representing the remote peer
		# @param description [Object] an object representing the remote session description
		#
		_onRemoteDescription: ( remote, description ) =>
			if remote is @id
				description = new RTCSessionDescription(description)
				@_connection.setRemoteDescription(description)
