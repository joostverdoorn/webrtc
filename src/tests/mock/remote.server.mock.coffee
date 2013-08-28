#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [

	'library//models/remote.server'
	'library/node.structured'

	'library//models/collection'

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

		query: ( request, args..., callback ) ->
			callback( @_nodes )
