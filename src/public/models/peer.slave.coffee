define [
	'./peer._'
	], ( Peer ) ->

	# This class provides an implementation of Peer to represent slave
	#

	class SlavePeer extends Peer
		initialize: ( ) ->