define [
	'public/library/models/../models/remote.peer'

	'public/library/models/vector'
	'public/library/models/collection'
	], (RemotePeer, Vector, Collection ) ->

	class Peer extends RemotePeer

		connected = false

		initialize: ( @id, instantiate = true ) ->

			@coordinates = new Vector(0, 0, 0)
			@latency = 0
			@connected = true

		isConnected: ( ) ->
			return @connected

		disconnect: () ->
			@connected = false
			@trigger('disconnect')

		