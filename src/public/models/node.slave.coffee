define [
	'./node._'
	'public/models/peer.master'

	'jquery'
	], ( Node, Master, $ ) =>

	# Slave app class
	#

	class Node.Slave extends Node

		type: 'slave'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@server.on('master.add', ( id ) =>
				@_master = new Master(@, id)

				@_master.on('peer.channel.opened', ( ) =>
					@server.disconnect()
					@trigger('peer.channel.opened', @_master);
				)
			)