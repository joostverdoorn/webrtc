require [
	'app._'
	'models/peer.slave'
	], ( App, Slave ) =>

	# Master app class
	#

	class App.Master extends App
		type: 'master'

		initialize: ( ) ->
			@_slaves = []

			@_slaves.push(new Slave)
			console.log @_slaves

	window.App = new App.Master
