#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'library/helpers/vector'

	'underscore'
	], ( Vector, _ ) ->

	# A token in the network distribution algorithm
	class Token

		nodeId = null

		# Constructs a new token.
		#
		constructor: ( ) ->
			@id = Math.floor(Date.now() * Math.random())
			@timestamp = Date.now()
			@position = new Vector(0, 0, 0)
			@targetPosition = new Vector(0, 0, 0)
			@candidates = []

		# Serializes this token to a JSON string
		#
		# @return [String] the JSON string representing this token
		#
		serialize: ( ) ->
			position = @position?.serialize() or null

			object =
				id: @id
				nodeId: @nodeId
				timestamp: @timestamp
				position: position
				targetPosition: @targetPosition.serialize()

			return JSON.stringify(object)

		# Generates a token from a JSON string and returns this
		#
		# @param messageString [String] a string in JSON format
		# @return [Token] a new Token
		#
		@deserialize: ( tokenString ) ->
			object = JSON.parse(tokenString)
			token = new Token()
			token.id = object.id
			token.nodeId = object.nodeId
			token.timestamp = object.timestamp
			token.position = Vector.deserialize(object.position)
			token.targetPosition = Vector.deserialize(object.targetPosition)
			return token




