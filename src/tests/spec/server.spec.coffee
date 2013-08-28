#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
require.config
#	baseUrl: '../../',
	paths:
		'library/models/remote.server': '../tests/mock/remote.server.mock'
		'library/models/remote.peer': '../tests/mock/remote.peer.mock'
		'library/models/remote.client': '../tests/mock/remote.client.mock'
		'express': '../tests/mock/express.mock'
		'http': '../tests/mock/http.mock'

require [
	'../server'
	'library/models/remote.client'
	'express'
	'http'
	], ( Server, Client, express, http ) ->
		describe 'Server', ->

			server = null

			beforeEach ->
				server = new Server('.')

			describe 'when constructing', ->
				it 'should initialize own variables', ->
					now = Date.now()
					expect(server._initTime).not.toBeGreaterThan(now)
					expect(server._nodes.length).toBe(0)

				it 'should start up an Express-server', ->
					expect(server._app.get).not.toBe(undefined)
					expect(server._app.configure).not.toBe(undefined)

					describe 'when starting up', ->
						it 'should get configured to relay files', ->
							expect(server._app.configure).toHaveBeenCalled()
							expect(server._app.use).toHaveBeenCalled()
							expect(express.static).toHaveBeenCalled()
							expect(express.static.mostRecentCall.args).toEqual([
									'./public'
								])

						it 'should redirect to the controller.html', ->
							fakeRes = {
										writeHead: jasmine.createSpy('writeHead')
										write: jasmine.createSpy('write')
										end: jasmine.createSpy('end')
										redirect: jasmine.createSpy('redirect')
									}

							callArgs = server._app.get.mostRecentCall.args
							expect(callArgs[0]).toEqual('/controller/:nodeId')
							callArgs[1]({
									params: {
										nodeId: '123'
									}
								}, fakeRes)
							expect(fakeRes.writeHead).not.toHaveBeenCalled()
							expect(fakeRes.write).not.toHaveBeenCalled()
							expect(fakeRes.redirect.mostRecentCall.args).toEqual([
									'/controller.html?nodeId=123'
								])
							expect(fakeRes.end).toHaveBeenCalled()

				it 'should start listening on port 8080', ->
					expect(server._server.listen.mostRecentCall.args).toEqual([
							8080
						])

				describe 'logging in', ->
					it 'should create a new Remote.Client with the server as controller and a socket as connection', ->
						testObject = {
							a: 1
							b: 2
						}
						server.login(testObject)

						expect(Client.mostRecentCall.args).toEqual([
								server
								testObject
							])

					it 'should add the new Remote.Client to itself', ->
						testObject = {
							a: 1
							b: 2
						}
						spyOn(server, 'addNode')
						fakeClient = new Client(server, testObject)
						Client.andReturn(fakeClient)

						server.login(testObject)

						expect(server.addNode.mostRecentCall.args).toEqual([
								fakeClient
							])

					it 'should listen for any event on the Remote.Client', ->
						testObject = {
							a: 1
							b: 2
						}
						fakeClient = new Client(server, testObject)
						spyOn(fakeClient, 'on')
						Client.andReturn(fakeClient)

						server.login(testObject)

						callArgs = fakeClient.on.mostRecentCall.args
						expect(callArgs[0]).toEqual('*')

						spyOn(server, 'removeNode')
						callArgs[1]('disconnect')

						expect(server.removeNode.mostRecentCall.args).toEqual([
								fakeClient
							])

				describe 'when emitting', ->
					it 'should create a new message without a sender and relay it', ->
						spyOn(server, 'relay')

						server.emitTo('1', 'event', 1, 2, 3)

						expect(server.relay).toHaveBeenCalled()

						message = server.relay.mostRecentCall.args[0]
						expect(message.to).toBe('1')
						expect(message.from).toBe(null)
						expect(message.event).toBe('event')
						expect(message.args).toEqual([
								1
								2
								3
							])

				describe 'when relaying', ->
					it 'should check if the node exists and send it accordingly', ->
						spyOn(server, 'getNode').andReturn(false)

						fakeMessage = {
							to: '1'
						}

						server.relay(fakeMessage)

						sendSpy = jasmine.createSpy('send')
						server.getNode.andReturn({
								send: sendSpy
							})
						server.relay(fakeMessage)

						expect(sendSpy.mostRecentCall.args).toEqual([
								fakeMessage
							])

				describe 'when manipulating the nodes-list', ->
					it 'should be possible to add nodes', ->
						fakeNode1 = {
							a: 1
							b: 2
						}
						fakeNode2 = {
							c: 3
							d: 4
						}
						server.addNode(fakeNode1)
						server.addNode(fakeNode1)
						server.addNode(fakeNode2)
						savedNodes = server.getNodes()
						expect(savedNodes[0]).toEqual(fakeNode1)
						expect(savedNodes[1]).toEqual(fakeNode2)
						expect(savedNodes.length).toEqual(2)

					it 'should be possible to remove nodes', ->
						fakeNode1 = {
							a: 1
							b: 2
						}
						fakeNode2 = {
							c: 3
							d: 4
						}
						server.addNode(fakeNode1)
						server.addNode(fakeNode2)
						server.removeNode(fakeNode1)
						server.removeNode(fakeNode1)
						savedNodes = server.getNodes()
						expect(savedNodes[0]).toEqual(fakeNode2)
						expect(savedNodes.length).toEqual(1)

					it 'should be possible to find nodes by id', ->
						fakeNode1 = {
							a: 1
							b: 2
							id: '1'
						}
						fakeNode2 = {
							c: 3
							d: 4
							id: '2'
						}
						server.addNode(fakeNode1)
						server.addNode(fakeNode2)
						expect(server.getNode('1')).toEqual(fakeNode1)
						expect(server.getNode('2')).toEqual(fakeNode2)
						expect(server.getNode('3')).toEqual(null)

					it 'should be possible to find nodes by type', ->
						fakeNode1 = {
							a: 1
							b: 2
							type: 'supernode'
						}
						fakeNode2 = {
							c: 3
							d: 4
							type: 'node'
						}
						fakeNode3 = {
							e: 5
							f: 6
							type: 'node'
						}
						server.addNode(fakeNode1)
						server.addNode(fakeNode2)
						server.addNode(fakeNode3)
						expect(server.getNodes('supernode')).toEqual([
								fakeNode1
							])
						expect(server.getNodes('node')).toEqual([
								fakeNode2
								fakeNode3
							])
						allNodes = server.getNodes()
						expect(allNodes.length).toEqual(3)

				describe 'when queried', ->
					fakeNode1 = null
					fakeNode2 = null
					beforeEach ->
						fakeNode1 = {
							a: 1
							b: 2
							id: '1'
							serialize: ->
								return '[1]'
							query: ( name, fn ) ->
								fn('[[3],[4]]')
						}
						fakeNode2 = {
							c: 3
							d: 4
							id: '2'
							serialize: ->
								return '[2]'
							query: ( name, fn ) ->
								fn('[[5],[6]]')
						}

					it 'should reply "pong" to a "ping" query', ->
						callback = jasmine.createSpy('callback').andCallFake(( result ) ->
							expect(result).toBe('pong')
						)

						result = server.query('ping', callback)

						waitsFor(->
							return callback.wasCalled
						)

					it 'should reply all serialized nodes on a non-extensive "nodes" query', ->

						callback = jasmine.createSpy('callback').andCallFake(( result ) ->
							expect(result).toEqual([
								'[1]'
								'[2]'
							])
						)

						server.addNode(fakeNode1)
						server.addNode(fakeNode2)

						result = server.query('nodes', callback)

						waitsFor(->
							return callback.wasCalled
						)

					it 'should reply all queried serialized nodes on a extensive "nodes" query', ->
						callback = jasmine.createSpy('callback').andCallFake(( result ) ->
							expect(result).toEqual([
								'[[3],[4]]'
								'[[5],[6]]'
							])
						)

						server.addNode(fakeNode1)
						server.addNode(fakeNode2)

						result = server.query('nodes', undefined, true, callback)

						waitsFor(->
							return callback.wasCalled
						)

					it 'should reply null when something unknown is queried', ->
						callback = jasmine.createSpy('callback').andCallFake(( result ) ->
							expect(result).toEqual(null)
						)

						server.addNode(fakeNode1)
						server.addNode(fakeNode2)

						result = server.query('asfsdg', callback)

						waitsFor(->
							return callback.wasCalled
						)

				describe 'when timed', ->
					it 'should give precise incremental numbers representing the time', ->
						# Bad test, but Jasmine's mock clock does not allow faking Date.now() results...
						first = server.time()
						expect(server.time() - first).not.toBeLessThan(0)
