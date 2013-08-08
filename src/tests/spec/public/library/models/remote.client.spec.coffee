require.config
	baseUrl: '../../../../../'

require [
	'public//library/models/remote.client'
	'public/library/models/message'

	], ( Client, Message ) ->

	describe 'Remote.Client', ->

		client = null
		fakeController = null
		fakeConnection = null
		
		class FakeConnection
			id: '1'

			emit: ->
			on: ->
			disconnect: ->

		class FakeController

			class FakeServer
				emitTo: ->
			
			constructor: ->		
				@server = new FakeServer()

			id: '2'
			query: ->
			relay: ->
			time: -> Date.now()

		beforeEach ->
			fakeController = new FakeController()
			fakeConnection = new FakeConnection()

		describe 'when initialized', ->
			it 'should set own id to _connection.id', ->
				client = new Client(fakeController, fakeConnection)

				expect(client.id).toBe(fakeConnection.id)

			it 'should bind the message and disconnect event to the connection', ->
				called = []

				spyOn(fakeConnection, 'on').andCallFake( ( query, fn ) ->
						called.push query
					)
				client = new Client(fakeController, fakeConnection)

				expect(called).toEqual([
						'message'
						'disconnect'
					])

			it 'should listen for setSuperNode events', ->
				spyOn(Client.prototype, '_onSetSuperNode')
				client = new Client(fakeController, fakeConnection)

				client.trigger('setSuperNode')

				expect(Client.prototype._onSetSuperNode).toHaveBeenCalled()

			it 'should send queries for type and isSuperNode', ->
				called = []
				spyOn(Client.prototype, 'query').andCallFake( ( query, fn ) ->
						called.push query
					)
				client = new Client(fakeController, fakeConnection)

				expect(called).toEqual([
						'type'
						'isSuperNode'
					])

		describe 'when disconnecting', ->
			it 'should disconenct the _connection', ->
				client = new Client(fakeController, fakeConnection)
				spyOn(fakeConnection, 'disconnect')

				client.disconnect()

				expect(fakeConnection.disconnect).toHaveBeenCalled()

		describe 'when sending', ->
			it 'should relay the message to _connection.emit', ->
				client = new Client(fakeController, fakeConnection)
				spyOn(fakeConnection, 'emit')

				fakeMessage = new Message('a', 'b', 'event')
				client._send(fakeMessage)

				expect(fakeConnection.emit).toHaveBeenCalled()
				expect(fakeConnection.emit.mostRecentCall.args).toEqual([
						'message'
						fakeMessage.serialize()
					])

		describe 'when setting supernode status', ->
			it 'should set the local variable to the new one', ->
				client = new Client(fakeController, fakeConnection)
				client._onSetSuperNode(true)
				expect(client.isSuperNode).toBe(true)
				client._onSetSuperNode(false)
				expect(client.isSuperNode).toBe(false)

		describe 'when serialized', ->
			it 'should return an object with id, type and isSuperNode', ->
				client = new Client(fakeController, fakeConnection)

				expect(client.serialize()).toEqual({
						id: client.id
						type: client.type
						isSuperNode: client.isSuperNode
					})
