define [
	'public/scripts/models/entity._'
	'public/scripts/models/entity.cannon'

	'three'
	'jquery'
	], ( Entity, Cannon, Three, $ ) ->

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
			@angularDrag = 7
			@applyGravity = true

			@_loader.load('/meshes/ufo.js', ( geometry, material ) =>
				# Set up skinned geometry mesh.
				@mesh = new Three.SkinnedMesh(geometry, new Three.MeshFaceMaterial(material))
				material.skinning = true for material in @mesh.material.materials

				# Set up animations for the mesh.
				THREE.AnimationHandler.add(@mesh.geometry.animation)
				@animation = new Three.Animation(@mesh, 'ArmatureAction', Three.AnimationHandler.CATMULLROM)
				@animation.play()

				# Create our cannon.
				@cannon = new Cannon(@scene, @, transformations?.cannon)

				# Apply passed transformations.
				@applyTransformations(transformations)

				# Set the rotation axis order to YXZ.
				@rotation.order = 'YXZ'

				# Add the mesh to the scene and set loaded state.
				@scene.add(@mesh)
				@loaded = true			
			)

		# Updates the physics state of the player. Adds forces to simulate gravity and 
		# the propulsion system. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			unless @loaded
				return

			rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)

			# Add thrust straight downward from the player. 
			thrustVector = new Three.Vector3(0, 1, 0).applyQuaternion(rotationQuaternion)

			if @boost
				thrustVector.multiplyScalar(16 * @mass * dt)
			else
				thrustVector.multiplyScalar(5 * @mass * dt)			

			@addForce(thrustVector)
			
			# Attract player to a straight position with relation to the planet surface.
			levelRotation = @calculateLevelRotation()
			levelRotationQuaternion = new Three.Quaternion().setFromEuler(levelRotation)

			forceQuaternion = rotationQuaternion.clone().inverse().multiply(levelRotationQuaternion)
			force = new Three.Euler().setFromQuaternion(forceQuaternion)
			@addAngularForce(force)

			# Attract player y rotation to cannon y rotation
			@addAngularForce(new Three.Euler(0, @cannon.rotation.y / 2, 0, 'YXZ'))
			@cannon.addAngularForce(new Three.Euler(0, -@cannon.rotation.y / 2, 0, 'YXZ'))

			# Update physics.
			super(dt)	

			# Update our cannon.
			@cannon.update(dt)

			# Update alien animation.
			@animation.update(dt)

		# Calculates a level rotation with relation to the planet surface and returns
		# an euler representation of this rotation.
		#
		# @return [Three.Euler] the ideal (level) rotation.
		# 
		calculateLevelRotation: ( ) ->
			upVector = @position.clone().normalize()
			rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)

			localXVector = new Three.Vector3(1, 0, 0).applyQuaternion(rotationQuaternion)
			localZVector = new Three.Vector3().crossVectors(upVector, localXVector)

			rotationMatrix = new Three.Matrix4().lookAt(@position, localZVector.add(@position), upVector)

			levelRotation = new Three.Euler().setFromRotationMatrix(rotationMatrix, 'YXZ')
			return levelRotation

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
			transformations.cannon = @cannon?.getTransformations()

			return transformations