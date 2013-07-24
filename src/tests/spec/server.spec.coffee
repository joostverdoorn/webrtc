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
					expect(server._logs.length).toBe(0)

				it 'should listen for the "debug" event on all nodes', ->
					fakeNode = {
							id: '1'
						}
					server.addNode(fakeNode)
					server._nodes.trigger('debug', fakeNode, 1, 2, 3, 'testMessage')
					expect(server._logs).toEqual([
							[fakeNode.id].concat([1, 2, 3])
						])

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

						fakeRes = {
									writeHead: jasmine.createSpy('writeHead')
									write: jasmine.createSpy('write')
									end: jasmine.createSpy('end')
								}

						describe 'when /nodes is requested', ->
							callback = null

							beforeEach ->
								callback = server._app._getCallbacks['/nodes']
								fakeRes.writeHead.reset()
								fakeRes.write.reset()
								fakeRes.end.reset()

							it 'should return an empty list when there are no nodes', ->
								expect(callback).not.toBe(undefined)

								spyOn(server, 'getNodes').andReturn([])

								callback(null, fakeRes)

								expect(server.getNodes).toHaveBeenCalled()
								expect(fakeRes.writeHead.mostRecentCall.args).toEqual([
										200
										'Content-Type': 'application/json'
									])
								expect(fakeRes.write.mostRecentCall.args).toEqual([
										'[]'
									])
								expect(fakeRes.end.mostRecentCall.args).toEqual([])

							it 'should return all nodes within 5 seconds', ->
								jasmine.Clock.useMock()

								spyOn(server, 'getNodes').andReturn([{
										query: ->
									}])

								callback(null, fakeRes)

								expect(fakeRes.writeHead.mostRecentCall.args).toEqual([
										200
										'Content-Type': 'application/json'
									])

								expect(fakeRes.write).not.toHaveBeenCalled()
								jasmine.Clock.tick(5001)
								expect(fakeRes.write.mostRecentCall.args).toEqual([
										JSON.stringify({
											error: 'ERR_TIMEOUT'
										})
									])

							it 'should return all nodes', ->
								fakeNode1 = {
									a: 1
									id: '1'
									type: 'supernode'
									isSuperNode: true
									benchmark: 1
									latency: 1
									system: 'test1'
									query: jasmine.createSpy('query').andCallFake((name, fn) ->
											if name is 'peers'
												fn([
														'2'
													])
										)
								}
								fakeNode2 = {
									b: 2
									id: '2'
									type: 'node'
									isSuperNode: false
									benchmark: 2
									latency: 2
									system: 'test2'
									query: jasmine.createSpy('query').andCallFake((name, fn) ->
											if name is 'peers'
												fn([
														'1'
													])
										)
								}

								spyOn(server, 'getNodes').andReturn([
										fakeNode1
										fakeNode2
									])
								callback(null, fakeRes)
								expect(fakeRes.write.mostRecentCall.args).toEqual([
										'{"1":{"peers":["2"],"isSuperNode":true,"benchmark":1,"system":"test1","latency":1},"2":{"peers":["1"],"isSuperNode":false,"benchmark":2,"system":"test2","latency":2}}'
									])

						describe 'when /log is requested', ->
							callback = null

							beforeEach ->
								callback = server._app._getCallbacks['/log']
								fakeRes.writeHead.reset()
								fakeRes.write.reset()
								fakeRes.end.reset()

							it 'should write all logs back to the connection', ->
								server._logs.push([
										'1'
										'arg1'
										'arg2'
									])
								server._logs.push([
										'2'
										'arg3'
									])
								logs = []
								fakeRes.write.andCallFake(( message ) ->
										logs.push(message)
									)
								callback(null, fakeRes)
								expect(fakeRes.writeHead.mostRecentCall.args).toEqual([
										200
										'Content-Type': 'text/plain'
									])
								expect(logs).toEqual([
										'1: arg1 \n'
										'2: arg3 \n'
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
