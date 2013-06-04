define [
	'./peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent slave
	#

	class Peer.Master extends Peer

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			App.server.sendTo(@remote, 'slave.add', App.id)

			channel = @_connection.createDataChannel('a', @_channelConfiguration)
			@_addChannel(channel)
			
			@_connection.createOffer(@onLocalDescription)

		# Is called when a local description has been added. Will send this description
		# to the remote.
		#
		# @param description [RTCSessionDescription] the local session description
		#
		onLocalDescription: ( description ) =>
			@_connection.setLocalDescription(description)
			App.server.sendTo(@remote, 'description.set', description)

		# Is called when a remote description has been received.
		#
		# @param remote [String] a string representing the remote peer
		# @param description [Object] an object representing the remote session description
		#
		onRemoteDescription: ( remote, description ) =>
			if remote is @remote
				description = new RTCSessionDescription(description)
				@_connection.setRemoteDescription(description)
