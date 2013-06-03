require [
	'app._'
	'models/peer.master'
	], ( App, Master ) =>

	# Slave app class
	#

	class App.Slave extends App
		type: 'slave'

		initialize: ( ) ->

	window.App = new App.Slave
