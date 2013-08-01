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
		constructor: ( @world, @owner, args... ) ->
			@scene = @world.scene
			@_loader = new Three.JSONLoader()
			@_raycaster = new Three.Raycaster()
			@loaded = false
			
			@mass = 1
			@drag = .01
			@angularDrag = 0
			@applyGravity = false

			@velocity = new Three.Vector3(0, 0, 0)
			@angularVelocity = new Three.Euler(0, 0, 0, 'YXZ')
			
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
			@_dead = true
			@scene.remove(@mesh)
			@trigger('die', @position.clone(), @velocity.clone())

		# Adds a force to the forces stack. Forces will be applied next update.
		#
		# @param vector [Three.Vector3] the vector force to add
		#
		addForce: ( vector ) ->
			@_forces.push(vector)

		# Adds an angular force to the forces stack. Forces will be applied next update.
		#
		# @param vector [Three.Vector3] the vector force to add
		#
		addAngularForce: ( vector ) ->
			@_angularForces.push(vector)

		# Updates the entity by applying forces, calculating the resulting velocity
		# and setting the entity's position and rotation.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt, updatePosition = true, updateRotation = true ) ->
			# Don't update unless we're completely done loading
			unless @loaded
				return

			if @_dead
				return

			# Add gravitational force pointing toward the origin.
			if @applyGravity
				gravityForce = @position.clone().normalize().multiplyScalar(-9.81 * @mass * dt)
				@addForce(gravityForce)

			# Apply forces ...
			if updatePosition

				# Calculate our new position from the velocity.
				@position.add(@velocity.clone().multiplyScalar(dt))

				# Rudimentary way to detect of we're on the planet surface. This should
				# be replaced by collision detection.
				#if @position.length() < 300
				#	@position.normalize().multiplyScalar(300)
				#	@velocity = new Three.Vector3()

				if @owner
					currentLength = @position.length()
					planetRadius = @world.planet.geometry.boundingSphere.radius
					if currentLength < planetRadius
						position2 = @position.clone().normalize().multiplyScalar(planetRadius)
						@_raycaster.set(position2, position2.clone().negate())
						intersects = @_raycaster.intersectObject(@world.planet)
						for key, intersect of intersects
							surface = planetRadius - intersect.distance

							if currentLength < surface
								@trigger('impact.world', @position.clone(), @velocity.clone())
								@position.normalize().multiplyScalar(surface)

								@velocity = new Three.Vector3()
							break

				# Loop through all forces and calculate the acceleration.
				acceleration = new Three.Vector3(0, 0, 0)			
				while force = @_forces.pop()
					acceleration.add(force.clone().divideScalar(@mass))

				# Add the acceleration to the velocity.
				@velocity.add(acceleration)

				# Calculate the drag force. We assume a fluid density of 1.2 (air at 20 degrees C)
				# and a cross-sectional area of 1. Any larger or smaller area will have to be 
				# compensated by a larger or smaller @drag.
				dragForce = @velocity.clone().normalize().negate().multiplyScalar(.5 * 1.2 * @drag * @velocity.lengthSq())
				@velocity.add(dragForce.divideScalar(@mass))

			# ... and apply rotational forces. The method of applying rotational forces and 
			# mainly for using angular velocity may look a bit strange, but this does really
			# seem to be the best way of doing it.
			if updateRotation

				# Calculate the change of rotation for this time step ...
				angularDelta = @angularVelocity.clone()

				angularDelta.x *= dt
				angularDelta.y *= dt
				angularDelta.z *= dt

				angularDeltaQuaternion = new Three.Quaternion().setFromEuler(angularDelta)

				# ... and multiply this delta with the current rotation to get the new rotation.
				rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)		
				rotationQuaternion.multiply(angularDeltaQuaternion)
				@rotation.setFromQuaternion(rotationQuaternion)

				# Loop through all angular forces and calculate the angular acceleration.
				angularAccelerationQuaternion = new Three.Quaternion()
				while force = @_angularForces.pop()
					forceQuaternion = new Three.Quaternion().setFromEuler(force)
					angularAccelerationQuaternion.multiply(forceQuaternion)

				angularAcceleration = new Three.Euler().setFromQuaternion(angularAccelerationQuaternion, 'YXZ')

				# Apply the acceleration to the angular velocity
				@angularVelocity.x += angularAcceleration.x
				@angularVelocity.y += angularAcceleration.y
				@angularVelocity.z += angularAcceleration.z

				# Apply drag force to the angular velocity. This way of doing it is pretty
				# basic, but should be sufficient.
				@angularVelocity.x *= 1 - @angularDrag * dt
				@angularVelocity.y *= 1 - @angularDrag * dt
				@angularVelocity.z *= 1 - @angularDrag * dt

		# Applies information given in an object to the entity.
		#
		# @param info [Object] an object that contains the transformations
		#
		applyInfo: ( info ) =>
			unless info?
				console.log 'wtf'
				return

			if info.velocity?
				@velocity.fromArray(info.velocity)

			if info.angularVelocity?
				@angularVelocity.fromArray(info.angularVelocity)
			
			if info.position?
				@position.fromArray(info.position)
			
			if info.rotation?
				@rotation.fromArray(info.rotation)

		# Returns the current info in an object.
		#
		# @return [Object] an object of all the info
		#
		getInfo: ( ) =>
			info = 
				velocity: @velocity.toArray()
				angularVelocity: @angularVelocity.toArray()
				position: @position.toArray()
				rotation: @rotation.toArray()

			return info

		# Returns if the bounding sphere of this entity is colliding with a bounding sphere of a given set of objects
		#
		# @param [Entities] An Array of entities to be checked against
		#
		# @return [Boolean] whether or not a collision has been found
		isColliding: ( objects ) ->
			unless @mesh?.geometry
				return false

			selfRadius = @mesh.geometry.boundingSphere.radius
			for object in objects
				unless object.mesh?.geometry
					continue

				objectRadius = object.mesh.geometry.boundingSphere.radius
				if @position.distanceTo(object.position) < (objectRadius + selfRadius)
					return true

			return false
