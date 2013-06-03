require [
	'app._'
	'models/peer.master'
	], ( App, MasterPeer ) =>

	# Slave app class
	#

	class SlaveApp extends App
		initialize: ( ) ->

	window.SlaveApp = new SlaveApp
