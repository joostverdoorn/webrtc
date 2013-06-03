define [
	'./peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent master
	#

	class MasterPeer extends Peer
		initialize: ( ) ->