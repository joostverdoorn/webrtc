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
