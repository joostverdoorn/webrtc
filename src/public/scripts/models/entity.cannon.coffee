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
			@_cannonLoaded = false
			@_cannonBaseLoaded = false

			@_cannonBase = new Three.Mesh()

			@mass = 10
			@angularDrag = 5
			
			@_isReady = true			

			# Load the cannon mesh.
			@_loader.load('/meshes/cannon.js', ( geometry, material ) =>
				@mesh.geometry = geometry
				@mesh.material = new Three.MeshFaceMaterial(material)
				@player.mesh.add(@mesh)

				# Set the correct rotation order.
				@rotation.order = 'YZX'

				# Hang the cannon 1.1 meters below the UFO.
				@position.y -= 1.1

				# Apply transformations
				@applyTransformations(transformations)

				# Set the loaded state.
				@_cannonLoaded = true
				if @_cannonBaseLoaded
					@loaded = true
			)

			# Load the cannon base mesh.
			@_loader.load('/meshes/cannonBase.js', ( geometry, material ) =>
				@_cannonBase.geometry = geometry
				@_cannonBase.material = new Three.MeshFaceMaterial(material)
				@player.mesh.add(@_cannonBase)

				# Set the loaded state.
				@_cannonBaseLoaded = true
				if @_cannonLoaded
					@loaded = true
			)

		# Updates the physics state of the cannon. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			super(dt, false, true)

			# Rotate cannon base y to cannon y
			@_cannonBase.rotation.y = @rotation.y

			# Set a maximal angles for the cannon.
			if @rotation.z > Math.PI / 4
				@rotation.z = Math.PI / 4
			else if @rotation.z < -Math.PI / 3
				@rotation.z = -Math.PI / 3

			if @rotation.y > Math.PI / 2
				@rotation.y = Math.PI / 2
			else if @rotation.y < -Math.PI / 2
				@rotation.y = -Math.PI / 2

			if @rotation.x isnt 0
				@rotation.x = 0

		# Fires a projectile. Can be fired each second
		#
		fire: ( ) ->
			if @_isReady

				projectile = new Projectile(@scene, @world, @owner, @player, @)
				@_isReady = false

				setTimeout( =>
					@_isReady = true
				, 500)

				return projectile