define [
	'public/scripts/models/entity._'

	'three'
	], ( Entity, Three ) ->

	# This class implements player-specific properties for the entity physics object.
	#
	class Entity.Player extends Entity

		# Is called from the baseclass' constructor. Will set up player specific 
		# properties for the entity
		#
		# @param id [String] the string id of the player
		# @param callback [Function] the callback to call when the player finished loading
		#
		initialize: ( @id, callback ) ->
			@boost = false
			@mass = 100

			@_loader.load('/meshes/ufo.js', ( geometry, material ) =>
				@mesh.geometry = geometry
				@mesh.material = new Three.MeshFaceMaterial(material)

				callback?()
			)

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

			#liftVector.projectOnPlane(new Three.Vector3(0, 1, 0))
			@addForce(liftVector)

			# Gravity
			gravityVector = new Three.Vector3(0, -9.81, 0)
			@addForce(gravityVector)

			# Attract to stable pitch and roll
			@addAngularForce(new Three.Vector3(-@rotation.x * 7, 0, 0))
			@addAngularForce(new Three.Vector3(0, 0, -@rotation.z * 7))
			
			# Call baseclass' update to apply all forces
			super(dt)


