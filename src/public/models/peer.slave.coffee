define [
	'./peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent master
	#

	class Peer.Slave extends Peer

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@on('channel.open', @onChannelOpen)
			@on('channel.close', @onChannelClose)

		# Is called when the channel has opened.
		#
		onChannelOpen: ( ) ->
			console.log 'opened channel to slave'

		# Is called when the channel has closed.
		#
		onChannelClose: ( ) ->
			console.log 'closed channel to slave'

		# Is called when a local description has been added. Will send this description
		# to the remote.
		#
		# @param description [RTCSessionDescription] the local session description
		#
		_onLocalDescription: ( description ) =>
			@_connection.setLocalDescription(description)
			App.server.sendTo(@id, 'description.set', description)

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
