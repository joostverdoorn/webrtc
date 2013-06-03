define [
	'vendor/underscore'
	'vendor/adapter'
	], ( ) ->

	# This abstract base class provides webrtc connections to masters and slaves
	#

	class Peer
		constructor: ( ) ->
			@_connection = new RTCPeerConnection(null)

			_.defer @initialize

		# This method is called from the constructor and should be overridden by subclasses
		#
		initialize: ( ) ->

		ping: ( callback ) ->

		pong: ( ) ->

		onPong: ( ) ->