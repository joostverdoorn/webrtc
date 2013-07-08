define [
	'./node._'
	'public/models/peer'

	'jquery'
	], ( Node, Peer, $ ) ->

	# Slave node class
	#

	class Node.Slave extends Node

		type: 'slave'

		# This method will be called from the baseclass when it has been constructed.
		# It will request a list of master peers from the server and connect to one.
		# 
		initialize: ( ) ->
			@server.on('connect', =>
				@server.requestInfo('masters', ( masters ) =>
					@_addMaster(masters[masters.length - 1])
				)
			)
		
		# Adds a ,aster peer specified by id
		#
		# @param id [String] the id of the peer
		#
		_addMaster: ( id ) ->
			@master = new Peer(@, id)
			@master.connect()

			@master.on('peer.channel.opened', ( ) =>
				@server.disconnect()
				@trigger('peer.channel.opened', @_master);
			)
			