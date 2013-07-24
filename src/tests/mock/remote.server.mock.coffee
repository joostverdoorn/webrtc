define [

	'public/library//models/remote.server'
	'public/library/node'

	'public/library//models/collection'

	], (RemoteServer, Node, Collection ) ->

	class MockServer extends RemoteServer
		initialize: () ->
			@_mockTriggers = []
			@on = jasmine.createSpy('on').andCallFake(( name, fn ) =>
					@_mockTriggers.push(name)
				)

			@_nodes = new Collection()
			node = new Object()
			node.id = "node1"
			node.isSuperNode = false
			@_nodes.push(node)

			node = new Object()
			node.id = "node2"
			node.isSuperNode = true
			@_nodes.push(node)

		connect: ( ) ->

		query: ( request, callback ) ->
			callback( @_nodes )


