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
			@_loaded = false
			
			@mass = 1
			@drag = .01
			@angularDrag = 0
			@applyGravity = false

			@velocity = new Three.Vector3(0, 0, 0)
			@angularVelocity = new Three.Quaternion()
			
			@forces = []
			@angularForces = []

			@mesh = new Three.Mesh()
			
			# Create getters and setters for position and rotation.
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
			@forces.push(vector)

		# Adds an angular force to the forces stack. Forces will be applied next update.
		#
		# @param vector [Three.Vector3] the vector force to add
		#
		addAngularForce: ( vector ) ->
			@angularForces.push(vector)

		# Updates the entity by applying forces, calculating the resulting velocity
		# and setting the entity's position and rotation.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt, updatePosition = true, updateRotation = true ) ->
			# Don't update unless we're completely done loading
			unless @loaded
				return

			# Add gravitational force pointing toward the origin.
			if @applyGravity
				gravityForce = @position.clone().normalize().multiplyScalar(-9.81 * @mass * dt)
				@addForce(gravityForce)

			# Apply forces ...
			if updatePosition

				# Set our last position if we don't have one yet.
				unless @_lastPosition?
					@_lastPosition = @position.clone()

				# Calculate our current velocity by subtracting our current position
				# from our last position, and set our position as lastPosition to
				# calculate the velocity in the next loop.
				@velocity = @position.clone().sub(@_lastPosition).divideScalar(dt)
				@_lastPosition = @position.clone()

				# Loop through all forces and calculate the acceleration.
				acceleration = new Three.Vector3(0, 0, 0)			
				while force = @forces.pop()
					acceleration.add(force.clone().divideScalar(@mass))

				# Add the acceleration to the velocity.
				@velocity.add(acceleration)

				# Calculate the drag force. We assume a fluid density of 1.2 (air at 20 degrees C)
				# and a cross-sectional area of 1. Any larger or smaller area will have to be 
				# compensated by a larger or smaller @drag.
				dragForce = @velocity.clone().normalize().negate().multiplyScalar(.5 * 1.2 * @drag * @velocity.lengthSq())
				@velocity.add(dragForce.divideScalar(@mass))

				# Calculate our new position from the velocity.
				@position.add(@velocity.clone().multiplyScalar(dt))

				# Rudimentary way to detect of we're on the planet surface. This should
				# be replaced by collision detection.
				if @position.length() < 100
					@position.normalize().multiplyScalar(100)
					@velocity.projectOnPlane(@position)

			# ... and apply rotational forces
			if updateRotation

				# Set our last rotation if we don't have one yet.
				unless @_lastRotation?
					@_lastRotation = @rotation.clone()

				# Calculate our current angular velocity by subtracting our current rotation
				# from our last rotation, and set our rotation as lastRotation to
				# calculate the angular velocity in the next loop.
				rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)
				lastRotationQuaternion = new Three.Quaternion().setFromEuler(@_lastRotation)				
				
				@angularVelocity = rotationQuaternion.clone().inverse().multiply(lastRotationQuaternion)
				@_lastRotation = @rotation.clone()

				# Loop through all angular forces and calculate the angular acceleration.
				#angularAcceleration = new Three.Quaternion()
				while force = @angularForces.pop()
					forceQuaternion = new Three.Quaternion().setFromEuler(force)
					@angularVelocity.multiply(forceQuaternion)

				# #Calculate the angular velocity after drag.
				# @angularVelocity.slerp(new Three.Quaternion(), @angularDrag * dt)

				# Calculate our new rotation from the angular velocity
				targetRotationQuaternion = rotationQuaternion.clone()
				targetRotationQuaternion.slerp(rotationQuaternion.multiply(@angularVelocity), dt)

				# Calculate and set our new rotation from the angular velocity.				
				@rotation.setFromQuaternion(targetRotationQuaternion)

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