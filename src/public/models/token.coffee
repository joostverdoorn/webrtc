define [], ( ) ->

	class Token

		id = null
		timestamp = null
		nodeId = null
		releasedBy = null
		coordinates = null # only set in a local set of tokens
		point = null


		# Constructs a new token.
		#
		constructor: ( nodeId = null, releasedBy = null ) ->
			@id = Date.now()
			@timestamp = Date.now()
			@nodeId = nodeId
			@releasedBy = releasedBy

		# Serializes this token to a JSON string
		#
		# @return [String] the JSON string representing this token
		#
		serialize: ( ) ->
			object = 
				id: @id
				timestamp: @timestamp
				nodeId: @nodeId
				releasedBy: @releasedBy
				point: @point
			return JSON.stringify(object)

		# Generates a token from a JSON string and returns this
		#
		# @param messageString [String] a string in JSON format
		# @return [Token] a new Token 
		#
		@deserialize: ( tokenString ) ->
			object = JSON.parse(tokenString)
			token = new Token( object.nodeId, object.releasedBy)
			token.id = object.id
			token.timestamp = object.timestamp
			token.point = object.point
			return token




		