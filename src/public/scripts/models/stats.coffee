define [
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->

	class Stats extends Mixable
		@concern EventBindings

		constructor: ( ) ->
			@stats = {}

		addStat: ( name, values = {} ) ->
			unless @stats[name]
				@stats[name] = values

		mergeStats: ( newStats ) ->
			for name, stats of newScores
				@mergeStat(name, stats)
			@_triggerChange()

		mergeStat: ( stat, values ) ->
			unless @stats[stat]
				return

			for id, value of values
				if @stats[stat][id] > value
					@stats[stat][id] = value

		incrementStat: ( stat, id, increment = 1 ) ->
			unless @stats[stat]
				return

			unless @stats[stat][id]
				@stats[stat][id] = increment
				@_triggerChange()
				return

			@stats[stat][id] += increment
			@_triggerChange()

		getStat: ( stat, id, defaultValue = 0 ) ->
			unless @stats[stat]
				return

			unless @stats[stat][id]
				return defaultValue

			return @stats[stat][id]

		_triggerChange: ( ) ->
			@trigger('change', @stats)
