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

			

			@_loader.load('/meshes/ufo.js', ( geometry, material ) =>
				@mesh = new Three.SkinnedMesh(geometry, new Three.MeshFaceMaterial(material))
				material.skinning = true for material in @mesh.material.materials

				THREE.AnimationHandler.add(@mesh.geometry.animation)
				@animation = new Three.Animation(@mesh, 'ArmatureAction', Three.AnimationHandler.CATMULLROM)
				@animation.play()

				@scene.add(@mesh)
				@cannon.position = @position
				@rotation.order = 'ZXY'
				@applyTransformations(transformations)

				@velocity = new Three.Vector3(4, 0, 4)
			)

		# Updates the physics state of the player. Adds forces to simulate gravity and 
		# the propulsion system. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			


			#upVectorSphere = @createDebugSphere(upVector, 0xff0000)

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
				liftVector.multiplyScalar(5 * @mass * dt)			

			#liftVector.projectOnPlane(new Three.Vector3(0, 1, 0))
			@addForce(liftVector)

			# Attract to stable pitch and roll
			# console.log Math.atan2(upVector.y, upVector.x) - @rotation.x

			gravityVector = @position.clone().normalize().negate()
			#upVector = 

			vX = new Three.Vector3(Math.cos(@rotation.y), 0, Math.sin(@rotation.y)).projectOnPlane(upVector).normalize()
			vZ = vX.clone().cross(upVector).normalize()

			vXSphere = @createDebugSphere(vX, 0x00ff00)
			vZSphere = @createDebugSphere(vZ, 0x0000ff)

			rX = Math.atan2(vZ.y, vZ.z)
			rZ = Math.atan2(vX.y, vX.x)
			

			@addAngularForce(new Three.Vector3(rX - @rotation.x, 0, 0))
			@addAngularForce(new Three.Vector3(0, 0, rZ - @rotation.z))

			# Attract to cannon y rotation
			#@addAngularForce(new Three.Vector3(0, 7 * (@cannon.rotation.y - @rotation.y) % Math.PI * 2, 0))
			
			# Call baseclass' update to apply all forces
			super(dt)

			_.defer( => @scene.remove(upVectorSphere))
			_.defer( => @scene.remove(vXSphere))
			_.defer( => @scene.remove(vZSphere))


			@rotation.x = 0 # rX
			@rotation.z = rZ

			#@rotation.y += 0.001

			# And update our cannon
			@cannon.update(dt)

			@animation?.update(dt)


		# Applies transformation information given in an object to the entity.
		#
		# @param transformations [Object] an object that contains the transformations
		#
		applyTransformations: ( transformations ) =>
			console.log transformations.position

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

		createDebugSphere: ( vector, color ) ->
			radius = .2
			segments = 6
			rings = 8

			sphereMaterial = new THREE.MeshBasicMaterial( {color: color }) 


			sphere = new Three.Mesh(
				new Three.SphereGeometry(
					radius,
					segments,
					rings)
				, sphereMaterial)

			sphere.position = @position.clone().add(vector.clone().multiplyScalar(10))

			@scene.add(sphere)
			return sphere

