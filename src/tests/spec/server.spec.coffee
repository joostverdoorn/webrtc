require.config
	baseUrl: '../../',
	paths:
		'public/library/models/remote.server': 'tests/mock/remote.server.mock'
		'public/library/models/remote.peer': 'tests/mock/remote.peer.mock'
		'public/library/models/remote.client': 'tests/mock/remote.client.mock'
		'express': 'tests/mock/express.mock'
		'http': 'tests/mock/http.mock'

require [
	'server'
	'public/library/models/remote.client'
	], ( Server, Client ) ->
		describe 'Server', ->

			server = null
			
			describe 'when constructing', ->


				describe 'when constructed', ->		# To skip the lengthy initialization
					beforeEach ->
						server = new Server()

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

						it 'should listen for the disconnect event on the Remote.Client', ->
							testObject = {
								a: 1
								b: 2
							}
							fakeClient = new Client(server, testObject)
							spyOn(fakeClient, 'on')
							Client.andReturn(fakeClient)

							server.login(testObject)

							callArgs = fakeClient.on.mostRecentCall.args
							expect(callArgs[0]).toEqual('disconnect')

							spyOn(server, 'removeNode')
							callArgs[1]()

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
						it 'should reply "pong" to a "ping" query', ->
							result = server.query('ping')
							expect(result).toBe('pong')

						it 'should reply all serialized nodes on a "nodes" query', ->
							fakeNode1 = {
								a: 1
								b: 2
								id: '1'
								serialize: =>
									return '[1]'
							}
							fakeNode2 = {
								c: 3
								d: 4
								id: '2'
								serialize: =>
									return '[2]'
							}
							server.addNode(fakeNode1)
							server.addNode(fakeNode2)

							result = server.query('nodes')

							expect(result).toEqual([
									'[1]'
									'[2]'
								])

					describe 'when timed', ->
						it 'should give precise incremental numbers representing the time', ->
							# Bad test, but Jasmine's mock clock does not allow faking Date.now() results...
							first = server.time()
							expect(server.time() - first).not.toBeLessThan(0)
