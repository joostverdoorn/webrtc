#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'game/scripts/helpers/mixable'
	'game/scripts/helpers/mixin.eventbindings'

	'library/node.structured'

	'game/scripts/models/controller._'

	'game/scripts/models/world'
	'game/scripts/models/entity.player'
	'game/scripts/models/stats'

	'three'
	], ( Mixable, EventBindings, Node, Controller, World, Player, Stats, Three ) ->

	# This game class implements the node structure created in the library.
	# It uses three.js for the graphics.
	#
	class Game extends Mixable
		@concern EventBindings

		paused = true

		_lastUpdateTime = 0

		# This method will be called from the baseclass when it has been constructed.
		#
		constructor: ( @scene ) ->
			# Create node and controller.
			@node = new Node()
			@controller = new Controller()

			@stats = {}

			@node.onQuery
				stats: ( callback, stats ) =>
					Stats.mergeStats(@world.getPlayers(), stats)
					callback @stats

			# Create the world.
			@world = new World(@scene)

			# Listen to events.
			@world.on
				'die': ( id ) =>
					@node.broadcast('entity.die', id)
				'player.kill': ( killerEntity ) =>
					if killerEntity isnt @player
						killer = @world.getPlayer(killerEntity.ownerID)
						killer.stats.incrementStat('kills', 1)

					@node.broadcast('player.kill', killerEntity.id, killerEntity.ownerID, @player.id)
					@player?.stats.incrementStat('deaths', 1)
				'stats.change': ( stats ) =>
					@stats = stats
					@trigger('stats.change', stats)

			@node.server.once
				'connect': ( ) =>

			@node.on
				'joined': =>
					@node.off('joined')
					@trigger('joined')
				'left': =>
					console.log 'Left the network'

			@node.onReceive
				'player.list': ( list ) =>
					@world.createPlayer(id, false, info) for id, info in list
				'player.joined': ( id, info ) =>
					@world.createPlayer(id, false, info)
				'player.left': ( id ) =>
					@world.removePlayer(id)
				'player.update': ( id, info, message ) =>
					@world.applyPlayerInfo(id, info, message.timestamp)
				'player.fire': ( id, info, message ) =>
					@world.createProjectile(info, message.timestamp)
				'entity.die': ( id ) =>
					@world.removeEntityByID(id)
				'player.kill': ( killerEntityID, killerEntityOwnerID, killedPlayerID ) =>
					killee = @world.getPlayer(killedPlayerID)
					killee?.stats.incrementStat('deaths', 1)
					killer = @world.getPlayer(killerEntityOwnerID)
					if killee isnt killer
						killer?.stats.incrementStat('kills', 1)
					@world.removeEntityByID(killerEntityID)

		# Updates the phyics for all objects and renders the scene. Requests a new animation frame
		# to repeat this methods.
		#
		# @param timestamp [Integer] the time that has elapsed since the first requestAnimationFrame
		#
		update: ( timestamp ) =>
			dt = (timestamp - @_lastUpdateTime) / 1000

			# Apply input to player.
			if @player?.loaded and not @paused
				@player.fire() if @controller.Fire
				@player.boost = @controller.Boost

				@player.flyLeft = @controller.FlyLeft
				@player.flyRight = @controller.FlyRight
				@player.flyForward = @controller.FlyForward
				@player.flyBackward = @controller.FlyBackward

				@player.cannon.rotateLeft = @controller.RotateCannonLeft
				@player.cannon.rotateRight = @controller.RotateCannonRight
				@player.cannon.rotateUpward = @controller.RotateCannonUpward
				@player.cannon.rotateDownward = @controller.RotateCannonDownward

			# Update the world
			@world.update(dt, @player)

			# Request a new animation frame.
			@_lastUpdateTime = timestamp

			return dt

		# Starts the game by finding a spawnpoint and spawning the player.
		#
		# @param position [Three.Vector3] the position override to spawn the player
		#
		startGame: ( position = null ) ->
			randomRadial = ( ) =>
				Math.random() * Math.PI * 2

			sanePosition = false
			while sanePosition is false
				radius = @world.planet.mesh.geometry.boundingSphere.radius
				euler = new Three.Euler(randomRadial(), randomRadial(), randomRadial())
				quaternion = new Three.Quaternion().setFromEuler(euler)

				position = new Three.Vector3(0, radius, 0)
				position.applyQuaternion(quaternion)

				if intersect = @world.planet.getIntersect(position, 4, radius)
					position = intersect.point
					sanePosition = true

			@createPlayer(position)
			@paused = false

		# Spawns the player in the world.
		#
		# @param position [Three.Vector3] the position at which to spawn the player
		#
		createPlayer: ( position ) =>
			if @player and not @player._dead
				return

			@queryStats()

			@player = @world.createPlayer(@node.id, true, position: position.toArray())

			@broadcastInterval = setInterval( ( ) =>
				@node.broadcast('player.update', @player.id, @player.getInfo())
			, 200)

			if @player.new
				@player.on
					'fire': ( projectile ) =>
						@node.broadcast('player.fire', @player.id, projectile.getInfo())
					'die': ( ) =>
						@_onPlayerDied(@broadcastInterval)

			@node.broadcast('player.joined', @player.id, @player.getInfo())

		# Is called when the player dies. Will cancel timed updates that are
		# broadcasted into the network.
		#
		# @param interval [Integer] the player broadcast interval to cancel.
		#
		# @private
		#
		_onPlayerDied: ( interval ) =>
			clearInterval(interval)
			@trigger('player.died')

		# Returns the current network time.
		#
		# @return [Float] the network time
		#
		time: ( ) ->
			return @node.time()

		# Queries nearby nodes for their stats and merges the result to hopefully get complete stats
		#
		queryStats: ( ) =>
			@node.queryTo
				to: '*'
				request: 'stats'
				ttl: 2
				callback: ( stats ) =>
					if stats isnt null
						Stats.mergeStats(@world.getPlayers(), stats)
