require.config
	paths:
		'public': '../../public'

require [
	'public/models/remote._'
	'public/models/message'
	], ( Remote, Message ) ->

	describe 'Remote', ->

		remote = null
		fakeController = null

		beforeEach ->
			fakeController = {
				id: '1'
				query: ->
				relay: ->
			}
			spyOn(fakeController, 'query');
			spyOn(fakeController, 'relay');
			spyOn(Remote.prototype, 'initialize');
			spyOn(Remote.prototype, '_send');

			Remote.hashes = []

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
				expect(Remote.hashes.length).toBe(0)
				remote.trigger('message', message.serialize())
				remote.trigger('message', message.serialize())
				expect(Remote.hashes.length).toBe(1)

			it 'should limit the hashtable size to 1000', ->
				to = fakeController.id
				from = fakeController.id + '1'

				expect(Remote.hashes.length).toBe(0)
				for i in [0...1000]
					message = new Message(to, from, 'testEvent', i)

					# Trigger twice, hash is the same, so should only be processed once
					remote.trigger('message', message.serialize())
				
				expect(Remote.hashes.length).toBe(1000)

				# The next message should splice of 200 hashes and add this new one
				message = new Message(to, from, 'testEvent', 1000)
				remote.trigger('message', message.serialize())
				expect(Remote.hashes.length).toBe(801)

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

				expect(Remote.hashes.length).toBe(0)
				remote.send(message)
				remote.send(message)
				expect(Remote.hashes.length).toBe(1)
				expect(remote._send.callCount).toBe(2)