#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
require.config
	baseUrl: '../../../../../'

require [
	'public/library/models/message'
	], ( Message ) ->

	describe 'Message', ->

		message = null

		beforeEach ->
			message = new Message('a', 'b', 'event')

		describe 'when constructed', ->

			it 'should have a receiver', ->
				expect(message.to).toBeDefined()

			it 'should have a sender', ->
				expect(message.from).toBeDefined()

			it 'should have an event', ->
				expect(message.event).toBeDefined()

			it 'should have a timestamp', ->
				expect(message.timestamp).toBeGreaterThan(0)

		describe 'when serialized', ->

			it 'should return a string', ->
				string = message.serialize()
				expect(typeof string).toBe('string')

			it 'should be able to be deserialized', ->
				string = message.serialize()
				newMessage = Message.deserialize(string)
				expect(newMessage instanceof Message).toBeTruthy()

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

		describe 'when its hash is stored', ->

			it 'should have increased the stored hashes\' length', ->
				storage = []
				length = storage.length
				message.storeHash(storage)
				expect(storage.length).toBeGreaterThan(length)

			it 'should not increase the stored hashes\' length to above 1000', ->
				storage = []
				for i in [0..1001]
					message = new Message(i, i, i, i)
					message.storeHash(storage)

				expect(storage.length).toBeLessThan(1000)

			it 'should say that its message is stored', ->
				storage = []
				message.storeHash(storage)
				expect(message.isStored(storage)).toBe(true)



