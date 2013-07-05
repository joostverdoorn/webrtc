define [
	'./node._'
	'public/models/peer.slave'
	
	'jquery'
	], ( Node, Slave, $ )->

	class Node.Master extends Node

		type: 'master'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@_slaves = []

			@server.on('slave.add', ( id ) =>
				slave = new Slave(@, id)
				@_slaves.push(slave)

				slave.on('peer.disconnected', ( ) =>
					@_slaves = _(@_slaves).without slave
				)

				@trigger('slave.add', slave)
			)		