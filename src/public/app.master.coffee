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

			@server.on('slave.add', ( id ) =>
				@_slaves.push(new Slave(id))
			)		

	window.App = new App.Master
