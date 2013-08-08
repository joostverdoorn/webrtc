define [], ( ) ->

	# Vector class. Extends Array and as such provides most of it's functionality.
	# This class is used for all Matrix operations
	#
	class Vector extends Array

		# Constructs a new Vector.
		#
		# @param args... [Float] Matrix values. The length of args decides the dimension of the matrix
		#
		constructor: (args...) ->
			super()
			for i in args
				@push(i)
			
		# Adds one Vector to another
		#
		# @param v [Vector] A Vector to be added
		# @return [Vector] Answer of the operation
		#
		add: ( v ) ->
			sum = new Vector()

			for i in [0...@length]
				sum.push( @[i] + v[i] )
			return sum

		# Subtracts one Vector from another
		#
		# @param v [Vector] A Vector to be subtracted
		# @return [Vector] Answer of the operation
		#
		subtract: ( v ) ->
			res = new Vector()

			for i in [0...@length]
				res.push( @[i] - v[i] )
			return res

		# Scales the Vector
		#
		# @param scaler [Float] A scaler to apply to the vector
		# @return [Vector] Answer of the operation
		#
		scale: ( scaler ) ->
			res = new Vector()

			for i in [0...@length]
				res.push( @[i] * scaler )
			return res

		# Calculates the distance between two Vectors
		#
		# @param v [Vector] A Vector to calculate to calculate the distance
		# @return [Float] Returns the distance
		#
		getDistance: ( v ) ->
			distance = 0
			for i in [0...@length]
				difference = @[i] - v[i]
				distance += Math.pow(difference, 2)
			distance = Math.sqrt(distance)
			return distance

		# Calculates the length of a Vector. The same as @getDistance (zeroVector)
		#
		# @return [Float] Returns the length of an array.
		#
		getLength: ( ) ->
			distance = 0
			for i in [0...@length]
				distance += Math.pow(@[i], 2)
			distance = Math.sqrt(distance)
			return distance

		# Calculates the unit vector of self
		#
		# @return [Vector] Returns the unit vector
		#
		unit: ( ) ->
			res = new Vector()
			length = @getLength()
			for i in [0...@length]
				res.push( @[i] / length )
			return res

		# Constructs a Zero vector
		#
		# @param dim [Int] A Dimension of desired Vector
		# @return [Vector] Returns a Zero Vector
		#
		@createZeroVector: ( dim ) ->
			res = new Vector()
			for i in [0...dim]
				res.push(0)
			return res

		# Serializes this vector to a JSON string
		#
		# @return [String] the JSON string representing this vector
		#
		serialize: ( ) ->
			return JSON.stringify(@)

		# Generates a vector from a JSON string and returns this
		#
		# @param vectorString [String] a string in JSON format
		# @return [Vector] a new Vector
		#
		@deserialize: ( vectorString ) ->
			object = JSON.parse(vectorString)
			res = new Vector()
			for i in [0...object.length] by 1
				res.push(object[i])
			return res