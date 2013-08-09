define [
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'

	'public/scripts/models/entity.planet'
	'public/scripts/models/entity.player'
	'public/scripts/models/entity.projectile'
	'public/scripts/models/collection'

	'underscore'
	'three'
	], ( Mixable, EventBindings, Planet, Player, Projectile,  Collection, _, Three ) ->

	# This class manages the game world.
	#
	# @concern EventBindings
	#
	class World extends Mixable

		@concern EventBindings

		# Constructs a new world
		#
		# @param scene [Three.Scene] the scene to draw upon
		#
		constructor: ( @scene ) ->
			@_loader = new Three.JSONLoader()

			@_entities = new Collection()
			@_entities.on('die', ( entity ) => @removeEntity(entity))

			# Add lights to the scene.
			directionalLight = new Three.DirectionalLight(0xffffff, 2)
			directionalLight.position.set(0, 1, 1).normalize()
			directionalLight.castShadow = true
			directionalLight.shadowDarkness = .5
			@scene.add(directionalLight)

			hemisphereLight = new Three.HemisphereLight(0x999999, 0x999999)
			@scene.add(hemisphereLight)

			# Create planet.
			@planet = new Planet(@, false)
			@planet.position = new Three.Vector3(0, 0, 0)

		# Adds a physics entity to the world
		#
		# @param entity [Entity] the entity to add
		#
		addEntity: ( entity ) ->
			@_entities.add(entity)

		# Removes a physics entity from the world
		#
		# @param entity [Entity] the entity to remove
		#
		removeEntity: ( entity ) ->
			@_entities.remove(entity)

		# Creates and adds a player to the world.
		#
		# @param id [String] the string id of the player
		# @param info [Object] an object of the player's info
		#
		createPlayer: ( id, owner, info, timestamp ) ->
			player = new Player(@, owner, id, info, timestamp)

			if owner
				player.on('fire', ( projectile ) => @addEntity(projectile))

			@addEntity(player)
			return player

		# Removes a player from the world.
		#
		# @param id [String] the id string of the player
		#
		removePlayer: ( id ) ->
			if player = @getPlayer(id)
				player.die()

		# Finds a player by id and returns it.
		#
		# @param id [String] the id string of the player
		# @return [Entity.Player] the player when found or null otherwise
		#
		getPlayer: ( id ) ->
			return _(@getPlayers()).find( ( player ) -> player.id is id)

		# Returns all players added to the world.
		#
		# @return [Array] an array of all players in the world
		#
		getPlayers: ( ) ->
			return _(@_entities).filter( ( entity ) -> entity instanceof Player)

		# Updates a player's info. If the player doesn't exist,
		# it will create the player using addPlayer().
		#
		# @param id [String] the string id of the player
		# @param info [Object] an object of the player's info
		#
		applyPlayerInfo: ( id, info, timestamp ) ->
			if player = @getPlayer(id)
				player.applyInfo(info, timestamp)
			else @createPlayer(id, false, info)

		# Creates a new projectile.
		#
		# @param info [Object] the object containing the projectile info
		#
		createProjectile: ( info, timestamp ) ->
			projectile = new Projectile(@, false, null, null, info)
			@addEntity(projectile)

		getSurface: ( position = new Three.Vector3(0, 1, 0)) ->
			radius = @planet.geometry.boundingSphere.radius
			pos = position.clone().normalize().multiplyScalar(radius)
			raycaster = new Three.Raycaster(pos, pos.clone().negate())
			objects = raycaster.intersectObject(@planet)
			if objects.length > 0
				objects[0].distance = radius - objects[0].distance
				return objects[0]

			return null

		# Updates the world.
		#
		# @param dt [Float] the time that has elapsed since last update
		# @param ownPlayer [Entity] entity to check against collisions with projectiles
		#
		update: ( @dt, ownPlayer ) ->
			entity?.update(dt) for entity in @_entities

			entities = _(@_entities).filter( ( entity ) -> entity instanceof Projectile and not entity.owner)
			if entities
				if ownPlayer?.isColliding(entities)
					ownPlayer.die()
