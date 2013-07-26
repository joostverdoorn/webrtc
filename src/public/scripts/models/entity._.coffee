define [ 
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'
	'public/scripts/helpers/mixin.dynamicproperties'

	'three'
	], ( Mixable, EventBindings, DynamicProperties, Three ) ->

	# Baseclass for all physics entities
	#
	class Entity extends Mixable
		@concern EventBindings
		@concern DynamicProperties

		# Constructs a new basic physics entity. Baseclass for other entities.
		# Will call initialize on the subclass.
		#
		# @param args... [Any] any params to pass onto the subclass
		# @param callback [Function] the function to call when the entity is loaded
		#
		constructor: ( @scene, args... ) ->
			@_loader = new Three.JSONLoader()
			@applyGravity = false
			@mass = 1
			@drag = .01
			@angularDrag = .5

			@velocity = new Three.Vector3(0, 0, 0)
			@angularVelocity = new Three.Vector3(0, 0, 0)
			
			@forces = []
			@angularForces = []

			@mesh = new Three.Mesh()
			
			@getter
				position: -> @mesh.position
				rotation: -> @mesh.rotation

			@setter
				position: ( vector ) -> @mesh.position = vector
				rotation: ( euler ) -> @mesh.rotation = euler

			@rotation.order = 'YXZ'

			@initialize?.apply(@, args)

		# Removes the mesh from the scene.
		#
		die: ( ) ->
			@scene.remove(@mesh)

		# Adds a force to the forces stack. Forces will be applied next update.
		#
		# @param vector [Three.Vector3] the vector force to add
		#
		addForce: ( vector ) ->
			# rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)
			# vector.applyQuaternion(rotationQuaternion)
			
			@forces.push(vector)

		# Adds an angular force to the forces stack. Forces will be applied next update.
		#
		# @param vector [Three.Vector3] the vector force to add
		#
		addAngularForce: ( vector ) ->
			# rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)
			# vector.applyQuaternion(rotationQuaternion)

			@angularForces.push(vector)

		# Updates the entity by applying forces, calculating the resulting velocity
		# and setting the entity's position and rotation.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt, updatePosition = true, updateRotation = true ) ->
			if @applyGravity
				gravityForce = @position.clone().normalize().multiplyScalar(-9.81 * @mass * dt)
				@addForce(gravityForce)

			# Apply forces ...
			if updatePosition				
				while force = @forces.pop()
					acceleration = force.clone().divideScalar(@mass)
					@velocity.add(acceleration)

				# Calculate the drag force. We assume a fluid density of 1.2 (air at 20 degrees C)
				# and a cross-sectional area of 1. Any larger or smaller area will have to be 
				# compensated by a larger or small @drag.
				dragForce = @velocity.clone().normalize().negate().multiplyScalar(.5 * 1.2 * @drag * @velocity.lengthSq())
				@velocity.add(dragForce.divideScalar(@mass))

				@position.x += @velocity.x * dt
				@position.y += @velocity.y * dt
				@position.z += @velocity.z * dt

				if @position.length() < 100
					@position.normalize().multiplyScalar(100)
					@velocity.projectOnPlane(@position)

			# ... and rotational forces.
			if updateRotation
				while force = @angularForces.pop()
					acceleration = force.clone().divideScalar(@mass)
					@angularVelocity.add(acceleration)

				@angularVelocity.multiplyScalar(1 - @angularDrag * dt)
				
				@rotation.x = (@rotation.x + @angularVelocity.x * dt) % (Math.PI * 2)
				@rotation.y = (@rotation.y + @angularVelocity.y * dt) % (Math.PI * 2)
				@rotation.z = (@rotation.z + @angularVelocity.z * dt) % (Math.PI * 2)

		# Applies transformation information given in an object to the entity.
		#
		# @param transformations [Object] an object that contains the transformations
		#
		applyTransformations: ( transformations ) =>
			unless transformations?
				return

			if transformations.velocity?
				@velocity.fromArray(transformations.velocity)

			if transformations.angularVelocity?
				@angularVelocity.fromArray(transformations.angularVelocity)
			
			if transformations.position?
				@position.fromArray(transformations.position)
			
			if transformations.rotation?
				@rotation.fromArray(transformations.rotation)

		# Returns the current transformation information in an object.
		#
		# @return [Object] an object of all the transformations
		#
		getTransformations: ( ) =>
			transformations = 
				velocity: @velocity.toArray()
				angularVelocity: @angularVelocity.toArray()
				position: @position.toArray()
				rotation: @rotation.toArray()

			return transformations