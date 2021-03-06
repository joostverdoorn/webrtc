#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'game/scripts/helpers/mixable'
	'game/scripts/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->

	# Object to save persistent data about peers in memory
	class Stats extends Mixable
		@concern EventBindings

		# Initialize the stats with an empty object
		#
		constructor: ( ) ->
			@stats = {}

		# Add the ability to store a new stat type
		#
		# @param name [String] The name of the stat
		# @param value [Numeral] The default value of this stat
		#
		addStat: ( name, value = 0 ) ->
			unless @stats[name]
				@stats[name] = value

		# Merges stats with player objects
		#
		# @param players [Array<Player>] The players to merge with
		# @param stats [Object] The new stats
		#
		@mergeStats: ( players, stats ) ->
			unless stats
				return

			for player in players
				if player.id? and stats[player.id]?
					player.stats.mergeStats(stats[player.id])

		# Merges stats with this object
		#
		# @param stats [Object] the new stats
		#
		mergeStats: ( stats ) ->
			for statName of @stats
				@mergeStat(statName, stats[statName])

		# Merges a single stat with this object
		#
		# @param statName [String] Which state to merge
		# @param value [Numeral] What to merge it with
		#
		mergeStat: ( statName, value ) ->
			if value > @stats[statName]
				@stats[statName] = value
				@_triggerChange()

		# Increments a numeral stat
		#
		# @param stat [String] which stat
		# @param increment [Numeral] Increase by how much
		#
		incrementStat: ( stat, increment = 1 ) ->
			unless @stats[stat]
				@stats[stat] = increment
				@_triggerChange()
				return

			@stats[stat] += increment
			@_triggerChange()

		# Retrieves the value of a stat
		#
		# @param statName [String] which stat
		# @param defaultValue [Any] what to return when this stat does not exist
		#
		getStat: ( statName, defaultValue = 0 ) ->
			unless @stats[statName]
				return defaultValue

			return @stats[statName]

		# Trigger a change event on this object, only used in case we want to do this in a different way later on to prevent multiple code changes then
		#
		# @private
		_triggerChange: ( ) ->
			@trigger('change', @stats)
