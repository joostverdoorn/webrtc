define [
	'vendor/underscore'
	'vendor/adapter'
	], ( ) ->

	# This abstract base class provides webrtc connections to masters and slaves
	#

	class Peer

		# Constructs a new peer. 
		#
		# @param remote [String] the string representing the remote peer
		#
		constructor: ( @remote ) ->
			@_connection = new RTCPeerConnection(null)
			@_connection.onicecandidate = @iceCallback

			App.server.on('description.set', @onRemoteDescription)
			App.server.on('candidate.add', @onCandidateAdd)

			@initialize()

		# This method is called from the constructor and should be overridden by subclasses
		#
		initialize: ( ) ->

		# Provides a callback for adding ice candidates. When a candidate is present,
		# call candidate.add on the remote to add it.
		#
		# @param event [Event] the event thrown
		#
		iceCallback: ( event ) =>
			if event.candidate?
				App.server.sendTo(@remote, 'candidate.add', event.candidate)

		# Is called when the remote wants to add an ice candidate
		#
		# @param remote [String] the id of the remote
		# @param candidate [Object] an object representing the ice candidate
		#
		onCandidateAdd: ( remote, candidate ) =>
			if remote is @remote
				candidate = new RTCIceCandidate(candidate)
				@_connection.addIceCandidate(candidate)

		ping: ( callback ) ->

		pong: ( ) ->

		onPong: ( ) ->