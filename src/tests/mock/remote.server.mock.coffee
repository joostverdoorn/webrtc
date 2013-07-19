define [

	'public/library/models/../models/remote.server'

	'public/library/models/../models/collection'
	'public/../tests/mock/remote.peer.mock'

	], (RemoteServer, Peer ) ->

	class MockServer extends RemoteServer


		connect: ( ) ->


