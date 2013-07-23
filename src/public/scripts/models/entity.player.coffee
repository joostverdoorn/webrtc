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

			@applyTransformations(transformations)

			@_loader.load('/meshes/ufo.js', ( geometry, material ) =>
				@mesh.geometry = geometry
				@mesh.material = new Three.MeshFaceMaterial(material)				
				@scene.add(@mesh)
			)

			@cannon = new Cannon(@scene, transformations?.cannon)
			@cannon.mesh.position = @position

		# Updates the physics state of the player. Adds forces to simulate gravity and 
		# the propulsion system. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			# Lift
			liftVector = new Three.Vector3()
			vector1 = new Three.Vector3(0, Math.sin(@rotation.x), -Math.cos(@rotation.x))
			vector2 = new Three.Vector3(Math.cos(@rotation.z), Math.sin(@rotation.z), )

			liftVector.crossVectors(vector1, vector2).normalize().negate()

			if @boost
				liftVector.multiplyScalar(12)
			else
				liftVector.multiplyScalar(9.5)

			liftVector.projectOnPlane(new Three.Vector3(0, 1, 0))
			@addForce(liftVector)

			# Gravity
			#gravityVector = new Three.Vector3(0, -9.81, 0)
			#@addForce(gravityVector)

			# Attract to stable pitch and roll
			@addAngularForce(new Three.Vector3(-@rotation.x * 7, 0, 0))
			@addAngularForce(new Three.Vector3(0, 0, -@rotation.z * 7))

			if @cannon.rotation.y - @rotation.y > (Math.PI / 6)
				@addAngularForce(new Three.Vector3(0, 2, 0))
			else if (@cannon.rotation.y - @rotation.y) < -(Math.PI / 6)
				@addAngularForce(new Three.Vector3(0, -2, 0))
			
			# Call baseclass' update to apply all forces
			super(dt)

			# And update our cannon
			@cannon.update(dt)


			

			console.log @rotation.y


		# Applies transformation information given in an object to the entity.
		#
		# @param transformations [Object] an object that contains the transformations
		#
		applyTransformations: ( transformations ) ->
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

