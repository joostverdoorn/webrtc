require.config
	paths:
		'public': '../../public'

require [
	'public/library/models/remote.client'
	'public/library/helpers/mixable'
	'public/library/helpers/mixin.eventbindings'

	], ( Client, Mixable, EventBindings ) ->

	describe 'Remote.Client', ->

		client = null
		fakeController = null
		fakeConnection = null

		# Fake RTCPeerConnection object to prevent actually connecting with something
		fakeRTC = null

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

			it 'should send queries for benchmark, system and isSuperNode', ->
				called = []
				spyOn(Client.prototype, 'query').andCallFake( ( query, fn ) ->
						called.push query
					)
				client = new Client(fakeController, fakeConnection)

				expect(called).toEqual([
						'benchmark'
						'system'
						'isSuperNode'
					])

		describe 'when disconnecting', ->
			it 'should disconenct the _connection', ->
				client = new Client(fakeController, fakeConnection)
				spyOn(fakeConnection, 'disconnect')

				client.disconnect()

				expect(fakeConnection.disconnect).toHaveBeenCalled()