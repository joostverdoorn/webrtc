#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'library//models/remote.peer'

	'library/models/vector'
	'library/models/collection'
	], (RemotePeer, Vector, Collection ) ->

	class Peer extends RemotePeer

		connected = false

		initialize: ( @id, @instantiate = true ) ->

			@coordinates = new Vector(0, 0, 0)
			@latency = 0
			@connected = true

		isConnected: ( ) ->
			return @connected

		disconnect: () ->
			@connected = false
			@trigger('disconnect')
