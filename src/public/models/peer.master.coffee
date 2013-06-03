define [
	'./peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent master
	#

	class Peer.Master extends Peer
		initialize: ( ) ->