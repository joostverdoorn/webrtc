define [], ( ) ->

	class Message

		@hashes = []

		# Constructs a new message.
		#
		# @param to [String] the id string of the intended receiver
		# @param from [String] the id string of the sender
		# @param event [String] the event to send
		# @param args [Array<Any>] any arguments to pass along with the message
		#
		constructor: ( @to, @from, @event, @args = [], @timestamp = null ) ->
			unless @timestamp?
				@timestamp = Date.now()

			@_hash = @hash()
			Object.freeze(@)

		# Serializes this message to a JSON string
		#
		# @return [String] the JSON string representing this message
		#
		serialize: ( ) ->
			object = 
				to: @to
				from: @from
				event: @event
				args: @args
				timestamp: @timestamp
			return JSON.stringify(object)

		# Generates a unique hash for this message to check for duplicates.
		# We use the djb2 hashing method described here: 
		# http://erlycoder.com/49/javascript-hash-functions-to-convert-string-into-integer-hash-
		# as it provides excellent speed vs distribution.
		#
		# @return [String] the hash of this message
		#
		hash: ( ) ->
			string = @serialize()
			hash = 5381;

			for i in [0...string.length] 
				char = string.charCodeAt(i)
				hash = ((hash << 5) + hash) + char
		
			return hash

		# Stores this message's hash in the static hash array for later lookup
		#
		storeHash: ( ) ->
			Message.hashes.push(@_hash)
			unless Message.hashes.length < 1000
				Message.hashes.splice(0, 200)

		# Returns true if and only if this message was already hashed and stored
		#
		# @return [Boolean] wether or this message was already stored
		#
		isStored: ( ) ->
			return @_hash in Message.hashes

		# Generates a message from a JSON string and returns this
		#
		# @param messageString [String] a string in JSON format
		# @return [Message] a new Message 
		#
		@deserialize: ( messageString ) ->
			object = JSON.parse(messageString)
			return new Message(object.to, object.from, object.event, object.args, object.timestamp)
