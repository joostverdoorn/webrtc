define [
	'public/scripts/models/entity._'
	'public/scripts/models/entity.cannon'

	'three'
	], ( Entity, Cannon, Three ) ->

	# This class implements player-specific properties for the entity physics object.
	#
	class Entity.Player extends Entity

		# Is called from the baseclass' constructor. Will set up player specific 
		# properties for the entity
		#
		# @param id [String] the string id of the player
		# @param transformations [Object] an object containing all transformations to apply to the player
		#
		initialize: ( @id, transformations = null ) ->
			@boost = false
			
			@mass = 100
			@drag = .01
			@applyGravity = true

			@cannon = new Cannon(@scene, @, transformations?.cannon)
			@cannon.position = @position
			@applyTransformations(transformations)

			@_loader.load('/meshes/ufo.js', ( geometry, material ) =>
				@mesh.geometry = geometry
				@mesh.material = new Three.MeshFaceMaterial(material)				
				@scene.add(@mesh)
			)

		# Updates the physics state of the player. Adds forces to simulate gravity and 
		# the propulsion system. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			# Lift
			liftVector = new Three.Vector3()

			# First, we get the two vectors that span the plane orthogonal to the up vector
			vector1 = new Three.Vector3(0, Math.sin(@rotation.x), -Math.cos(@rotation.x))
			vector2 = new Three.Vector3(Math.cos(@rotation.z), Math.sin(@rotation.z), 0)

			liftVector.crossVectors(vector1, vector2).normalize().negate()

			x = liftVector.x
			z = liftVector.z

			liftVector.x = x * Math.cos(@rotation.y) + z * Math.sin(@rotation.y)
			liftVector.z = z * Math.cos(@rotation.y) - x * Math.sin(@rotation.y)

			if @boost
				liftVector.multiplyScalar(12 * @mass * dt)
			else
				liftVector.multiplyScalar(9.5 * @mass * dt)			

			#liftVector.projectOnPlane(new Three.Vector3(0, 1, 0))
			@addForce(liftVector)

			# Attract to stable pitch and roll
			@addAngularForce(new Three.Vector3(-@rotation.x * 7, 0, 0))
			@addAngularForce(new Three.Vector3(0, 0, -@rotation.z * 7))

			# Attract to cannon y rotation
			@addAngularForce(new Three.Vector3(0, 7 * (@cannon.rotation.y - @rotation.y) % Math.PI * 2, 0))
			
			# Call baseclass' update to apply all forces
			super(dt)

			# And update our cannon
			@cannon.update(dt)

		# Applies transformation information given in an object to the entity.
		#
		# @param transformations [Object] an object that contains the transformations
		#
		applyTransformations: ( transformations ) =>
			unless transformations
				return

			super(transformations)
			@cannon.applyTransformations(transformations.cannon)
			
		# Returns the current transformation information in an object.
		#
		# @return [Object] an object of all the transformations
		#
		getTransformations: ( ) ->
			transformations = super()
			transformations.cannon = @cannon.getTransformations()

			return transformations

