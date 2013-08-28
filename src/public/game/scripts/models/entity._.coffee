#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'game/scripts/helpers/mixable'
	'game/scripts/helpers/mixin.eventbindings'
	'game/scripts/helpers/mixin.dynamicproperties'

	'three'
	], ( Mixable, EventBindings, DynamicProperties, Three ) ->

	# Baseclass for all physics entities
	#
	class Entity extends Mixable
		@concern EventBindings
		@concern DynamicProperties

		@Loader = new Three.JSONLoader()

		# Constructs a new basic physics entity. Baseclass for other entities.
		# Will call initialize on the subclass.
		#
		# @param args... [Any] any params to pass onto the subclass
		# @param callback [Function] the function to call when the entity is loaded
		#
		constructor: ( @world, @ownerID, @owner, args... ) ->
			@scene = @world.scene
			@loaded = false

			@_updates = {}
			@_lastUpdate = 0

			@mass = 1
			@drag = .01
			@angularDrag = 0
			@applyGravity = false

			@velocity = new Three.Vector3(0, 0, 0)
			@angularVelocity = new Three.Euler(0, 0, 0, 'YXZ')

			@_forces = []
			@_angularForces = []

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

		# Removes the mesh from the scene and stops simulation
		#
		die: ( ) ->
			@_dead = true
			@scene.remove(@mesh)
			@trigger('die', @position.clone(), @velocity.clone())

		# Revives an object by re-adding it to the scene and making sure the gameloop includes it again in sumulations
		#
		revive: ( ) ->
			@_dead = false
			@scene.add(@mesh)

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

		# Given a time difference since the last update this will update the position of the entity
		#
		# @param dt [Float] the time since the last calculation
		# @param owner [Boolean] are we the owner of this entity
		# @private
		#
		_updatePosition: ( dt ) ->
			# Calculate our new position from the velocity.
			deltaPosition = @velocity.clone().multiplyScalar(dt)
			@position.add(deltaPosition)

			# Apply dead reckoning of position.
			if @_targetPosition and not @owner
				@_targetPosition.add(deltaPosition)

				if @position.distanceTo(@_targetPosition) > 20
					@position = @_targetPosition.clone()
				else
					@position.lerp(@_targetPosition, dt)

			triggerImpact = ( intersect ) =>
				@trigger('impact.world', @position.clone(), @velocity.clone())

				@position = intersect.point
				@velocity = new Three.Vector3()

			# Check if the player intersects with the planet.
			if intersect = @world.planet.isInside(@position)
				@die()
			if @owner
				if intersect = @world.planet.getIntersect(@position, 4, 0)
					triggerImpact(intersect)

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

		# Given a time difference since the last update this will update the rotation of the entity
		#
		# @param dt [Float] the time since the last calculation
		# @private
		#
		_updateRotation: ( dt ) ->
			# Calculate the change of rotation for this time step ...
			angularDelta = @angularVelocity.clone()

			angularDelta.x *= dt
			angularDelta.y *= dt
			angularDelta.z *= dt

			angularDeltaQuaternion = new Three.Quaternion().setFromEuler(angularDelta)

			# ... and multiply this delta with the current rotation to get the new rotation.
			rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)
			rotationQuaternion.multiply(angularDeltaQuaternion)

			# Apply dead reckoning of rotation.
			if @_targetRotation and not @owner
				targetRotationQuaternion = new Three.Quaternion().setFromEuler(@_targetRotation)
				targetRotationQuaternion.multiply(angularDeltaQuaternion)
				rotationQuaternion.slerp(targetRotationQuaternion, dt)

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

		# Updates the entity by applying forces, calculating the resulting velocity
		# and setting the entity's position and rotation.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt, ownPlayer, updatePosition = true, updateRotation = true ) ->
			# Don't update unless we're completely done loading
			unless @loaded
				return

			if @_dead
				return

			# Add gravitational force pointing toward the origin.
			if @applyGravity
				gravityDirection = @position.clone().normalize().negate()
				gravityForce = gravityDirection.multiplyScalar(9.81 * @mass * dt)
				@addForce(gravityForce)

			# Update position if requested
			if updatePosition
				@_updatePosition(dt)

			# ... and update rotation by applying rotational forces. The method of applying rotational forces and
			# mainly for using angular velocity may look a bit strange, but this does really
			# seem to be the best way of doing it.
			if updateRotation
				@_updateRotation(dt)

			# Reset force queues
			@_forces = []
			@_angularForces = []

			# History
			unless @owner
				@_updates[App.time()] =
					position: @position
					rotation: @rotation

		# Applies information given in an object to the entity.
		#
		# @param info [Object] an object that contains the transformations
		#
		applyInfo: ( info, timestamp = null ) =>
			unless info?
				return

			if info.id
				@id = info.id

			if info.ownerID
				@ownerID = info.ownerID

			# We received a timed update. From it we will compute
			# the target position, and rotation, and slowly ease
			# toward it. This will look much better and will be more
			# accurate than setting the position and rotation directly.
			if timestamp? and timestamp > @_lastUpdate
				# Extract position and rotation from info object
				infoPosition = new Three.Vector3().fromArray(info.position)
				infoRotation = new Three.Euler().fromArray(info.rotation)

				# Get updates behind and ahead of timestamp
				previousTime = 0
				for time, update of @_updates

					# This update's time is smaller, but we don't
					# know if the next update is, so we remove the one
					# before the current.
					if time < timestamp
						delete @_updates[previousTime]
						previousTime = time

					# We have found the two updates!
					else
						behind = @_updates[previousTime]
						ahead = update
						break

				# When we found the updates, we will apply the delta position
				# and delta rotation that happened since that update to the
				# the received info and set the resultant position and rotation
				# as our target position and target rotation.
				if behind? and ahead?
					# Get the time fraction between the two updates at which the
					# info was sent.
					deltaTime = time - previousTime
					fraction = (timestamp - previousTime) / deltaTime

					# Get the target position.
					position = behind.position.clone().lerp(ahead.position, fraction)
					deltaPosition = @position.clone().sub(position)
					@_targetPosition = infoPosition.clone().add(deltaPosition)

					# Get the target rotation.
					behindRotation = behind.rotation.clone()
					aheadRotation = ahead.rotation.clone()

					rotation = new Three.Quaternion().setFromEuler(behindRotation)
					rotation.slerp(new Three.Quaternion().setFromEuler(aheadRotation), fraction)
					deltaRotation = new Three.Quaternion().setFromEuler(@rotation)
					deltaRotation.multiply(rotation.inverse())

					targetRotation = new Three.Quaternion().setFromEuler(infoRotation)
					targetRotation.multiply(deltaRotation)
					@_targetRotation = new Three.Euler().setFromQuaternion(targetRotation)

				# Else we will just set our target position and target rotation
				# directly.
				else
					@_targetPosition = infoPosition
					@_targetRotation = infoRotation

				@_lastUpdate = timestamp

			# We didn't receive a timed update. Just set the position and rotation
			# directly.
			else
				if info.position?
					@position.fromArray(info.position)

				if info.rotation?
					@rotation.fromArray(info.rotation)

			# Always just set the received velocity and angular velocity.
			if info.velocity?
				@velocity.fromArray(info.velocity)

			if info.angularVelocity?
				@angularVelocity.fromArray(info.angularVelocity)


		# Returns the current info in an object.
		#
		# @return [Object] an object of all the info
		#
		getInfo: ( ) =>
			info =
				id: @id
				velocity: @velocity.toArray()
				angularVelocity: @angularVelocity.toArray()
				position: @position.toArray()
				rotation: @rotation.toArray()
				ownerID: @ownerID

			return info

		# Checks if this entity's origin intersects with a mesh, and returns the intersect
		# object. Specify behind and ahead values to broaden intersection check.
		#
		# @param mesh [Three.Mesh] the mesh to check against
		# @param behind [Float] the distance behind this entity to check from
		# @param ahead [Float] the distance in ahead of this entity to check to
		# @return [Object] the intersect object
		#
		getIntersect: ( point, behind, ahead ) ->
			radius = @mesh.geometry.boundingSphere.radius
			distance = @position.distanceTo(point)

			if distance <= radius
				direction = @position.clone().sub(point).normalize()
				origin = @position.clone().add(direction.clone().negate().setLength(distance + behind))


				# origin = @position.clone().add(@position.clone().setLength(behind))
				raycaster = new Three.Raycaster(origin, direction, 0, behind + ahead)

				intersects = raycaster.intersectObject(@mesh)
				if intersect = intersects[0]
					intersect.distance -= behind
					return intersect
				else
					return @isInside(point)

		# Determines if a point is inside this object
		#
		# @param point [Three.Vector3] the point to check
		# @return [Collision] Returns a fake ThreeJS collision object if the point is inside; null otherwise
		isInside: ( point ) ->
			radius = @mesh.geometry.boundingSphere.radius
			distance = @position.distanceTo(point)
			if distance <= radius / 2
				return {
					distance: 0
					point: point.clone()
					face:
						normal: new Three.Vector3()
				}
			else
				return null

		# Returns if the bounding sphere of this entity is colliding with a bounding sphere
		# of a given set of objects.
		#
		# @param [Array<Entity>] an array of entities to be checked against
		# @return [Boolean] whether or not a collision has been found
		#
		isColliding: ( entities ) ->
			unless @mesh?.geometry?.boundingSphere?.radius
				return false

			selfRadius = @mesh.geometry.boundingSphere.radius
			for entity in entities
				unless entity.mesh?.geometry?.boundingSphere?.radius
					continue

				entityRadius = entity.mesh.geometry.boundingSphere.radius
				if @position.distanceTo(entity.position) < (entityRadius + selfRadius)
					return entity

			return false
