require.config
	baseUrl: '../../../../../'

require [
	'public/library/models/collection'
	'public/library/helpers/mixable'
	'public/library/helpers/mixin.eventbindings'
	], ( Collection, Mixable, EventBindings ) ->

	describe 'Collection', ->

		collection = null
		class Obj extends Mixable
			@concern EventBindings

		beforeEach ->
			collection = new Collection()

		describe 'when created', ->
			
			it 'should be empty', ->
				expect(collection.length).toBe(0)

			it 'should be possible to add an object', ->
				expect( -> collection.add(3)).not.toThrow()

		describe 'when adding an object to an empty collection', ->

			length = null
			obj = null

			beforeEach ->
				obj = new Obj()

				length = collection.length
				collection.add(obj)

			it 'should have increased the collection\'s length', ->
				expect(collection.length).toBeGreaterThan(length)

			it 'should remove duplicate objects when adding the same object', ->
				collection.add(obj)
				expect(collection.length).toEqual(1)

			it 'should be possible to bind to events the object throws', ->
				fn = jasmine.createSpy()
				collection.on('event', fn)
				obj.trigger('event')
				expect(fn).toHaveBeenCalled()

			it 'should be possible to listen only once to events the object throws', ->
				fn = jasmine.createSpy()
				collection.once('event', fn)
				obj.trigger('event')
				obj.trigger('event')
				expect(fn.callCount).toEqual(1)

			it 'should be possible to retrieve the object', ->
				expect(collection[0]).toBe(obj)

			it 'should be possible to remove the object', ->
				collection.remove(obj)
				expect(collection.length).toEqual(0)

		describe 'when removing an object from a populated collection', ->

			obj1 = null
			obj2 = null
			obj3 = null

			beforeEach ->
				obj1 = new Obj()
				obj2 = new Obj()
				obj3 = new Obj()

				collection.add(obj1)
				collection.add(obj2)
				collection.add(obj3)

			it 'should have decreased the collection\'s length', ->
				length = collection.length
				collection.remove(obj1)
				expect(collection.length).toBeLessThan(length)

			it 'should no longer be possible to listen to events of the object', ->
				fn = jasmine.createSpy()
				collection.on('event', fn)
				collection.remove(obj1)
				obj1.trigger('event')
				expect(fn).not.toHaveBeenCalled()


