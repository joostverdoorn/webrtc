define [
	'vendor/underscore'
	], ( ) ->

	# This abstract base class provides webrtc connections to masters and slaves
	#

	class Peer
		constructor: ( ) ->
			_.defer @initialize

		# This method is called from the constructor and should be overridden by subclasses
		#
		initialize: ( ) ->