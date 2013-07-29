define [
	'public/scripts/models/entity._'
	'public/scripts/models/entity.projectile'

	'three'
	], ( Entity, Projectile, Three ) ->

	# This class implements the cannon hanging from the ufo
	#
	class Entity.Cannon extends Entity

		# Is called from the baseclass' constructor. 
		#
		# @param transformations [Object] an object containing all transformations to apply to the player
		#
		initialize: ( @player, transformations = null ) ->
			@mass = 10
			@angularDrag = 5
			
			@_isReady = true			

			@_loader.load('/meshes/cannon.js', ( geometry, material ) =>
				@mesh.geometry = geometry
				@mesh.material = new Three.MeshFaceMaterial(material)
				@player.mesh.add(@mesh)

				@applyTransformations(transformations)

				@loaded = true
			)

		# Updates the physics state of the cannon. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			super(dt, false, true)

		# Fires a projectile. Can be fired each second
		#
		fire: ( ) ->
			if @_isReady

				projectile = new Projectile(@scene, @player, @)
				@_isReady = false

				setTimeout( =>
					@_isReady = true
				, 500)

				return projectile