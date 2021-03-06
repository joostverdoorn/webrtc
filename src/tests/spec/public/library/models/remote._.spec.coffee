#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
#require.config
#	baseUrl: '../../../../../'

require [
	'library/models/remote._'
	'library/models/message'
	], ( Remote, Message ) ->

	describe 'Remote', ->

		remote = null
		fakeController = null

		beforeEach ->
			fakeController = {
				id: '1'
				query: (request, args..., callback) -> callback(true)
				relay: ->
				time: -> return Date.now()
				messageStorage: []
			}
			spyOn(fakeController, 'query').andCallThrough()
			spyOn(fakeController, 'relay')
			spyOn(Remote.prototype, 'initialize')
			spyOn(Remote.prototype, '_send')

			Message.hashes = []

			remote = new Remote(fakeController, 1, 2)

		describe 'when constructed', ->

			it 'should have the given controller', ->
				expect(remote._controller).toEqual(fakeController)

			it 'should have called @initialize with the constructor arguments', ->
				expect(remote.initialize).toHaveBeenCalledWith(1, 2)

		describe 'when killed', ->

			it 'should remove all listeners', ->
				spyOn(remote, 'off')
				spyOn(remote, 'isConnected').andReturn(false)
				spyOn(remote, 'disconnect')
				remote.die()
				expect(remote.off).toHaveBeenCalled()
				expect(remote.disconnect).not.toHaveBeenCalled()

			it 'should disconnect if there is a connection', ->
				spyOn(remote, 'isConnected').andReturn(true)
				spyOn(remote, 'disconnect')
				remote.die()
				expect(remote.disconnect).toHaveBeenCalled()

		describe 'when receiving a message', ->

			it 'should discard the same message coming in', ->
				to = fakeController.id
				from = fakeController.id + '1'
				message = new Message(to, from, 123, 'testEvent')

				# Trigger twice, hash is the same, so should only be processed once
				expect(fakeController.messageStorage.length).toBe(0)
				remote.trigger('message', message.serialize())
				remote.trigger('message', message.serialize())
				expect(fakeController.messageStorage.length).toBe(1)

			it 'should trigger the event from the message on our instance if `to` is our controller', ->
				to = fakeController.id
				from = fakeController.id + '1'
				message = new Message(to, from, 123, 'testEvent', 1000)

				remote.on('testEvent', ( number ) =>
						expect(number).toBe(1000)
					)
				remote.trigger('message', message.serialize())

			it 'should relay messages that are not for our controller', ->
				to = fakeController.id + '1'
				from = fakeController.id
				message = new Message(to, from, 123, 'testEvent', 1000)

				remote.on('testEvent', ( number ) =>
						throw "Should not parse this event"
					)
				remote.trigger('message', message.serialize())

				expect(fakeController.relay).toHaveBeenCalledWith(message)

			it 'should relay and parse messages that for `*`', ->
				to = '*'
				from = fakeController.id
				message = new Message(to, from, 'testEvent', 1000)

				remote.on('testEvent', ( number ) =>
						expect(number).toBe(1000)
					)
				remote.trigger('message', message.serialize())

				expect(fakeController.relay).toHaveBeenCalledWith(message)

		describe 'when sending', ->

			it 'should hash the message and send it', ->
				to = fakeController.id
				from = fakeController.id + '1'
				message = new Message(to, from, 'testEvent')

				expect(fakeController.messageStorage.length).toBe(0)
				remote.send(message)
				remote.send(message)
				expect(fakeController.messageStorage.length).toBe(1)
				expect(remote._send.callCount).toBe(2)

		describe 'when pinged', ->

			it 'should send a ping query', ->
				spyOn(remote, 'query')

				callbackCalled = false
				remote.ping(( args... )->
						callbackCalled = args
						expect(args[0]).not.toBeLessThan(0)
						expect(args).toEqual([
								remote.latency
								1
								2
								3
							])
					)
				expect(remote.query).toHaveBeenCalled()
				remote.query.mostRecentCall.args[1]('pong', 1, 2, 3)

			it 'should only respond to pong events', ->
				spyOn(remote, 'query')

				callback = jasmine.createSpy()

				remote.ping(callback)
				expect(remote.query).toHaveBeenCalled()
				remote.query.mostRecentCall.args[1]('plong', 1, 2, 3)
				expect(callback).not.toHaveBeenCalled()
