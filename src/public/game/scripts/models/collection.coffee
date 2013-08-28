#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'game/scripts/helpers/mixable'
	'game/scripts/helpers/mixin.eventbindings'

	'underscore'
	], ( Mixable, EventBindings, _ ) ->

	# Collection class. Extends Array and as such provides most of it's functionality.
	# The value of this class is in that it is easy to add and remove items, but mainly
	# in that it is possible to listen to all members of the collection at once.
	#
	class Collection extends Array

		_.extend(@, Mixable)
		@concern EventBindings

		# Constructs a new Collection.
		#
		constructor: ->
			super()

		# Adds an object to the collection. The collection will listen on any
		# event the object may throw, and trigger it itself with the object
		# that threw the event as first argument.
		#
		# @param object [Object] the object to add to the collection
		#
		add: ( object ) ->
			@remove(object)
			@push(object)

			fn = ( event, args... ) =>
				args = [event, object].concat(args)
				@trigger.apply(@, args)

			object.on?('*', fn, @)

		# Removes an object from the collection. This will stop listening to the
		# object.
		#
		# @param object [Object] the object to remove
		#
		remove: ( object ) ->
			index = @indexOf(object)
			if index > -1
				@splice(index, 1)
				object.off?('*', null, @)
				return object




