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
				slave = new Pong(id)


				slave.on('peer.orientation', ( orientation ) =>
					if(@_slaves.indexOf(slave) is 0)
						player1.vSpeed += Math.round (orientation.roll/5)
					else
						player2.vSpeed += Math.round (orientation.roll/5)
				)

				slave.on ('peer.custom'), (custom) ->
					console.log(custom.value)

				slave.on('peer.disconnected', ( ) ->
					@_slaves = _(@_slaves).without slave
					elem.remove()
				)

				@_slaves.push(slave)
			)		

	window.App = new App.Masterpong
