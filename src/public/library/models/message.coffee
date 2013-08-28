#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'underscore'
	], ( _ ) ->

	# Message class. This provides the core messaging functionality of the network.
	#
	class Message

		# Constructs a new message.
		#
		# @param to [String] the id string of the intended receiver
		# @param from [String] the id string of the sender
		# @param timestamp
		# @param event [String] the event to send
		# @param args [Array<Any>] any arguments to pass along with the message
		# @param params [Object] an object of params
		# @option params path [Array<String>] an array of nodes by which to route the message
		# @option params route [Array<String>] an array of nodes which have routed this message
		# @option params ttl [Integer] the maximum number of hops the message may take
		#
		constructor: ( to, from, timestamp, event, args = [], params = {} ) ->
			if params.path? and params.path.length > 0
				message = new Message(to, from, timestamp, event, args)
				path = params.path

				path.reverse()
				for i in [0...path.length - 1]
					message = new Message(path[i], from, timestamp, 'relay', [message.serialize()])

				@to = path[path.length - 1]
				@from = from
				@timestamp = timestamp
				@event = 'relay'
				@args = [message.serialize()]
				@route = []

			else
				@to = to
				@from = from
				@timestamp = timestamp
				@event = event
				@args = args
				@ttl = params.ttl ? Infinity
				@route = params.route ? []

			@_hash = @hash()

		# Generates a unique hash for this message to check for duplicates.
		# We use the djb2 hashing method described here:
		# http://erlycoder.com/49/javascript-hash-functions-to-convert-string-into-integer-hash-
		# as it provides excellent speed vs distribution.
		#
		# @return [Integer] the hash of this message
		#
		hash: ( ) ->
			string = @serialize(false)
			hash = 5381

			for i in [0...string.length]
				char = string.charCodeAt(i)
				hash = ((hash << 5) + hash) + char

			return hash

		# Stores this message's hash a hash array for later lookup.
		#
		# @param storage [Array<Integer>] an array of message hashes
		#
		storeHash: ( storage ) ->
			unless storage[0]?
				storage[0] = []
			list = storage[0]

			if list.length is 1024

				unless storage[1]?
					storage[1] = []
				list = storage[1]

				if list.length is 1024
					storage[0] = storage[1]
					storage[1] = []
					list = storage[1]

			i = _(list).sortedIndex(@_hash)
			list.splice(i, 0, @_hash)

		# Returns true if and only if this message was already hashed and stored
		#
		# @param storage [Array<Integer>] an array of message hashes
		# @return [Boolean] wether or this message was already stored
		#
		isStored: ( storage ) ->
			unless storage[0]?
				return false

			if _(storage[0]).indexOf(@_hash, true) > -1
				return true

			unless storage[1]?
				return false

			if _(storage[1]).indexOf(@_hash, true) > -1
				return true

			return false

		# Disassembles a message into parts of a specified length, to be
		# reassembled at a later stage.
		#
		# @param maxLength [Integer] the maximum length of each message part
		# @return parts [Array<Object>] an array of message parts
		#
		disassemble: ( maxLength ) ->
			hash = @hash()
			messageString = @serialize()
			length = messageString.length

			n = Math.ceil(length / maxLength)
			parts = []

			for i in [0...n]
				part =
					hash: hash
					n: n
					i: i
					data:messageString.substr(maxLength * i, maxLength)
				parts.push(part)

			return parts

		# Reassembles a previously disassembled message.
		#
		# @param part [Object] a message part object
		# @param storage [Array<Object>] the storage array for partial messages
		# @return [Message] the assembled message, or null if the message isn't complete yet
		#
		@assemble: ( part, storage ) ->
			unless storage[part.hash]?
				storage[part.hash] = []

			storage[part.hash][part.i] = part.data
			if storage[part.hash].length < part.n
				return null

			messageString = ""
			for data in storage[part.hash]
				unless data? then return null
				messageString += data

			message = @deserialize(messageString)

			delete storage[part.hash]
			return message

		# Serializes this message to a JSON string
		#
		# @param includeMeta [Boolean] include changing metadata like routing table and TTL
		# @return [String] the JSON string representing this message
		#
		serialize: ( includeMeta = true ) ->
			object =
				t: @to
				f: @from
				ts: @timestamp
				e: @event
				a: @args

			if includeMeta
				object.ttl = @ttl
				object.r = @route

			return JSON.stringify(object)

		# Generates a message from a JSON string and returns this
		#
		# @param messageString [String] a string in JSON format
		# @return [Message] a new Message
		#
		@deserialize: ( messageString ) ->
			object = JSON.parse(messageString)

			return new Message(object.t, object.f, object.ts, object.e, object.a,
				ttl: object.ttl
				route: object.r
			)
