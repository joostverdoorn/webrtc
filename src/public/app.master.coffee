require [
	'app._'
	'models/peer.slave'
	], ( App, SlavePeer ) =>

	# Master app class
	#

	class MasterApp extends App
		initialize: ( ) ->
			@_slaves = []

	window.MasterApp = new MasterApp()
