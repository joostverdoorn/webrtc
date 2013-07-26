define [
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'

	'public/scripts/models/entity.player'
	'public/scripts/models/entity.projectile'
	'public/scripts/models/collection'

	'underscore'
	'three'
	], ( Mixable, EventBindings, Player, Projectile,  Collection, _, Three ) ->

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

			@_entities = new Collection()

			directionalLight = new Three.DirectionalLight(0xffffff, 2)
			directionalLight.position.set(0, 1, 1).normalize()
			@scene.add(directionalLight)

			ambientLight = new Three.AmbientLight(0xaaaaaa)
			@scene.add(ambientLight)

			# hemisphereLight = new Three.HemisphereLight(0x9999aa, 0x663322, 1)
			# @scene.add(hemisphereLight)

			planetMaterial = new Three.MeshLambertMaterial(
				color:0x00ff00
			) 

			radius = 100
			segments = 20
			rings = 20

			planet = new Three.Mesh(
				new Three.SphereGeometry(
					radius,
					segments,
					rings)
				, planetMaterial)

			@scene.add(planet)

		


		# Creates and adds a player to the world
		#
		# @param id [String] the string id of the player
		# @param transformations [Object] an object of the player's transformations
		#
		addPlayer: ( id, transformations ) ->
			player = new Player(@scene, id, transformations)
			@addEntity(player)

		# Updates a player's transformation in the world. If the player doesn't exist, 
		# it will create the player using addPlayer()
		#
		# @param id [String] the string id of the player
		# @param transformations [Object] an object of the player's tranfomrations
		#
		updatePlayer: ( id, transformations ) ->
			player = _(@_entities).find( ( entity ) -> entity instanceof Player and entity.id is id)
			if player?
				player.applyTransformations(transformations)
			else
				@addPlayer(id, transformations)

		drawProjectiles: ( projectileTransformations ) -> 
			projectile = new Projectile(@scene)
			@addEntity(projectile)		
			projectile.applyTransformations(projectileTransformations)


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

		# Updates the world.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( @dt ) ->
			entity.update(dt) for entity in @_entities
			
