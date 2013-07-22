define [

	'public/library/models/../models/remote.server'
	'public/library/node'

	'public/library/models/../models/collection'

	], (RemoteServer, Node, Collection ) ->

	class MockServer extends RemoteServer

		initialize: () ->

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


