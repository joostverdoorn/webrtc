define [
	'public/helpers/mixable'
	'public/helpers/mixin.eventbindings'

	'underscore'
	], ( Mixable, EventBindings, _ ) ->

	class Collection extends Array

		_.extend(@, Mixable)
		@concern EventBindings

		constructor: ->
			super()

		add: ( object ) ->
			@remove(object)
			@push(object)

			fn = ( event, args... ) =>
				args = [event, object].concat(args)
				@trigger.apply(@, args)
			
			object.on?('*', fn, @)

		remove: ( object ) ->
			if index = @indexOf(object) > -1
				@splice(index, 1)
				object.off?('*', null, @)




