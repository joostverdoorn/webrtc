require [
	'app._'
	'models/peer.slave'
	], ( App, Pong ) ->

	# Masterpong app class
	#

	class App.Masterpong extends App
		
		type: 'master'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@_slaves = []

			@server.on('slave.add', ( id ) =>
				# Generate a new Player
				slave = new Pong(id)
				@_slaves.push(slave)

				# keep count of Slaves
				num = @_slaves.indexOf(slave)
				@.printStatus("Player#{num+1} joined </br>")

				# Start the game when there are two players connected
				if(num  is 1)
					@.printStatus("Let's go!")
					start()

				# Manipulate controllers
				slave.on('peer.orientation', ( orientation ) =>
					if(num is 0)
						player1.vSpeed += Math.round (orientation.roll/5)
					else
						player2.vSpeed += Math.round (orientation.roll/5)
				)

				# Delete a slave when a player disconnects
				slave.on('peer.disconnected', ( ) =>
					@_slaves = _(@_slaves).without slave
					elem.remove()
					@.printStatus("Player#{num+1} disconnected</br>")

				)

				
			)	
		printStatus: (message) ->
			$("#log").html($("#log").html() + message)

	window.App = new App.Masterpong
