require [
	'app._'
	'models/peer.master'
	], ( App, Master ) =>

	# Slave app class
	#

	class App.Slave extends App
		
		type: 'slave'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@server.on('master.add', ( id ) =>
				@_master = new Master(id)
			)

	window.App = new App.Slave
