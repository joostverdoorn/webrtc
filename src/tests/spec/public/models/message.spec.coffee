require.config
	paths:
		'public': '../../public'

require [
	'public/models/message'
	], ( Message ) ->

	describe 'Message', ->

		message = null

		beforeEach ->
			message = new Message('a', 'b', 'event')

		describe 'when constructed', ->

			beforeEach ->
				message = new Message('a', 'b', 'event')

			it 'should have a receiver', ->
				expect(message.to).not.toBe(undefined)

			it 'should have a sender', ->
				expect(message.from).not.toBe(undefined)

			it 'should have an event', ->
				expect(message.event).not.toBe(undefined)

			it 'should have a timestamp', ->
				expect(message.timestamp).toBeGreaterThan(0)

		describe 'when serialized', ->

			it 'should return a string', ->
				string = message.serialize()
				expect(typeof string).toBe('string')

			it 'should be able to be deserialized', ->
				string = message.serialize()
				newMessage = Message.deserialize(string)
				expect(newMessage instanceof Message).toBe(true)

			it 'should be equal to its deserialized serial', ->
				string = message.serialize()
				newMessage = Message.deserialize(string)
				expect(newMessage).toEqual(message)

		describe 'when hashed', ->

			it 'should return a number', ->
				expect(typeof message.hash()).toBe('number')

			it 'should return a different value than other message\'s hash', ->
				otherMessage = new Message('c', 'd', 'otherEvent', ['q'])
				expect(message.hash()).not.toEqual(otherMessage.hash())
			


