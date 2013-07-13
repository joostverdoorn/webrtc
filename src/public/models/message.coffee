define [
	'murmurhash3'
	], ( MurmurHash3 ) ->

	class Message

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
		#
		# @return [String] the hash of this message
		#
		hash: ( ) ->
			string = @serialize()
			return MurmurHash3.hashString

		# Generates a message from a JSON string and returns this
		#
		# @param messageString [String] a string in JSON format
		# @return [Message] a new Message 
		#
		@deserialize: ( messageString ) ->
			object = JSON.parse(messageString)
			return new Message(object.to, object.from, object.event, object.args, object.timestamp)
