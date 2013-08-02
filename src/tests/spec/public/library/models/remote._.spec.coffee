require.config
	baseUrl: '../../../../../'

require [
	'public/library/models/remote._'
	'public/library/models/message'
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
				message = new Message(to, from, 'testEvent')

				# Trigger twice, hash is the same, so should only be processed once
				expect(Message.hashes.length).toBe(0)
				remote.trigger('message', message.serialize())
				remote.trigger('message', message.serialize())
				expect(Message.hashes.length).toBe(1)

			it 'should trigger the event from the message on our instance if `to` is our controller', ->
				to = fakeController.id
				from = fakeController.id + '1'
				message = new Message(to, from, 'testEvent', 1000)

				remote.on('testEvent', ( number ) =>
						expect(number).toBe(1000)
					)
				remote.trigger('message', message.serialize())

			it 'should relay messages that are not for our controller', ->
				to = fakeController.id + '1'
				from = fakeController.id
				message = new Message(to, from, 'testEvent', 1000)

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

		describe 'when emitting', ->

			it 'should create a message and send it', ->
				spyOn(remote, 'send')

				remote.emit('testEvent', 1)

				expect(remote.send).toHaveBeenCalled()

				# Check if argument is correct
				argument = remote.send.mostRecentCall.args[0]
				expect(argument instanceof Message).toBe(true)
				expect(argument.event).toBe('testEvent')
				expect(argument.args.length).toBe(1)
				expect(argument.args[0]).toBe(1)

			it 'should create a message with a specified receiver and send it', ->
				spyOn(remote, 'send')

				remote.emitTo('123', 'testEvent', 1)

				expect(remote.send).toHaveBeenCalled()

				# Check if argument is correct
				argument = remote.send.mostRecentCall.args[0]
				expect(argument instanceof Message).toBe(true)
				expect(argument.event).toBe('testEvent')
				expect(argument.args.length).toBe(1)
				expect(argument.args[0]).toBe(1)
				expect(argument.to).toBe('123')

		describe 'when sending', ->

			it 'should hash the message and send it', ->
				to = fakeController.id
				from = fakeController.id + '1'
				message = new Message(to, from, 'testEvent')

				expect(Message.hashes.length).toBe(0)
				remote.send(message)
				remote.send(message)
				expect(Message.hashes.length).toBe(1)
				expect(remote._send.callCount).toBe(2)

		describe 'when querying', ->

			it 'should create a one-time callback for the result and emit the request to the target', ->
				spyOn(remote, 'emit')

				called = 0
				remote.query('testQuery', 1, ->
						called++
					)

				expect(remote.emit).toHaveBeenCalled()
				callArgs = remote.emit.mostRecentCall.args
				expect(callArgs[1]).toBe('testQuery')
				queryID = callArgs[2]
				expect(callArgs[3]).toBe(1)
				expect(callArgs.length).toBe(4)

				remote.trigger(queryID)
				remote.trigger(queryID)
				expect(called).toBe(1)

		describe 'when queried', ->

			it 'should query the controller for the value and send it back to the node querying', ->
				message = {
					from: '1'
				}
				spyOn(remote, 'emitTo')

				remote._onQuery('testQuery', 'query1', 1, message)
				callArgs = fakeController.query.mostRecentCall.args
				expect(callArgs[0]).toBe('testQuery')
				expect(callArgs[1]).toBe(1)

				assertions = ( ) ->
					callArgs = remote.emitTo.mostRecentCall.args
					expect(callArgs[0]).toBe(message.from)
					expect(callArgs[1]).toBe('query1')
					expect(callArgs[2]).toBe(true)

				waitsFor(->
						called = remote.emitTo.wasCalled
						if called
							assertions()
						return called
					, 1000)

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

				waitsFor(->
						return callbackCalled isnt false
					, 1000)