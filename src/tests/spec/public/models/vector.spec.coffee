require.config
	paths:
		'public': '../../public'

require [
	'public/models/vector'
	], ( Vector ) ->

	describe 'Vector', ->

		a = null
		b = null
		c = null

		describe 'when constructed', ->

			beforeEach ->
			a = new Vector(3, 4, 5)
			b = new Vector(3, 2, 1)

			it 'should have a length', ->
				expect(a.length).toEqual(3)

			it 'should be possible to access the vector values', ->
				expect(a[2]).toEqual(5)
			
		describe 'basic operations: sum, substract, scale', ->
			
			beforeEach ->
				a = new Vector(3, 4, 5)
				b = new Vector(3, 2, 1)

			it 'should be able to sum the vectors', ->
				c = a.add(b)
				expect(c).toEqual(new Vector(6, 6, 6))

			it 'should be able to substract the vectors', ->
				c = a.substract(b)
				expect(c).toEqual(new Vector(0, 2, 4))

			it 'should be able to scale the vectors', ->
				c = a.scale(-2)
				expect(c).toEqual(new Vector(-6, -8, -10))

		describe 'line functions: getDistance and getLength', ->
			
			beforeEach ->
				a = new Vector(2, 3, -9)
				b = new Vector(5, 7, -9)
				c = new Vector(10, 8, -6)

			it 'should be able to calculate the distance between two vectors', ->			
				expect(a.getDistance(b)).toEqual(5)
				expect(Math.round(c.getDistance(a))).toEqual(10)

			it 'should be able to calculate the length of the vector', ->			
				expect(Math.round(a.getLength())).toEqual(10)
				expect(a.getLength()).toEqual(a.getDistance(new Vector(0,0,0)))

		describe 'unit vectors', ->

			beforeEach ->
				a = new Vector(1, 7, 8)

			it 'should be able to calculate the unit vector', ->
				expect(a.unit().getLength()).toEqual(1)

		describe 'zero vectors', ->

			it 'should be able to create a Zero Vector', ->
				expect(Vector.createZeroVector(5).length).toEqual(5)

			it 'should be zero of length', ->
				expect(Vector.createZeroVector(5).getLength()).toEqual(0)

		describe 'serialization', ->

			beforeEach ->
				a = new Vector(1, 7, 8)

			it 'should return a string', ->
				string = a.serialize()
				expect(typeof string).toBe('string')

			it 'should be able to be deserialized', ->
				string = a.serialize()
				b = Vector.deserialize(string)
				expect(b instanceof Vector).toBeTruthy()

			it 'should be equal to its deserialized serial', ->
				string = a.serialize()
				b = Vector.deserialize(string)
				expect(a).toEqual(b)



			
