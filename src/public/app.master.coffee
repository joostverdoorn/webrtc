require [
	'app._'
	'models/peer.slave'
	], ( App, Slave ) ->

	# Master app class
	#

	class App.Master extends App
		type: 'master'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@_slaves = []

			@_slaves.push(new Slave)
			console.log @_slaves

	window.App = new App.Master
