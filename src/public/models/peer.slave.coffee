define [
	'./peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent master
	#

	class Peer.Slave extends Peer

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->

		# Is called when a local description has been added. Will send this description
		# to the remote.
		#
		# @param description [RTCSessionDescription] the local session description
		#
		onLocalDescription: ( description ) =>
			@_connection.setLocalDescription(description)
			App.server.sendTo(@remote, 'description.set', description)

		# Is called when a remote description has been received. It will create an answer.
		#
		# @param remote [String] a string representing the remote peer
		# @param description [Object] an object representing the remote session description
		#
		onRemoteDescription: ( remote, description ) =>
			if remote is @remote
				description = new RTCSessionDescription(description)
				@_connection.setRemoteDescription(description)
				@_connection.createAnswer(@onLocalDescription, null, {})
