define [
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->

	class Stats extends Mixable
		@concern EventBindings

		constructor: ( ) ->
			@stats = {}

		addStat: ( name, value = 0 ) ->
			unless @stats[name]
				@stats[name] = value

		@mergeStats: ( players, stats ) ->
			for player in players
				if player.id? and stats[player.id]?
					player.stats.mergeStats(stats[player.id])

		mergeStats: ( stats ) ->
			for statName of @stats
				@mergeStat(statName, stats[statName])

		mergeStat: ( statName, value ) ->
			if value > @stats[statName]
				@stats[statName] = value
				@_triggerChange()

		incrementStat: ( stat, increment = 1 ) ->
			unless @stats[stat]
				@stats[stat] = increment
				@_triggerChange()
				return

			@stats[stat] += increment
			@_triggerChange()

		getStat: ( stat, id, defaultValue = 0 ) ->
			unless @stats[stat]
				return defaultValue

			return @stats[stat]

		_triggerChange: ( ) ->
			@trigger('change', @stats)
