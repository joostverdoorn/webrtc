define [
	'public/scripts/models/entity._'
	'public/scripts/models/entity.cannon'
	'public/scripts/models/entity.projectile'

	'three'
	], ( Entity, Cannon, Projectile, Three ) ->

	# This class implements player-specific properties for the entity physics object.
	#
	class Entity.Player extends Entity

		# Is called from the baseclass' constructor. Will set up player specific 
		# properties for the entity
		#
		# @param id [String] the string id of the player
		# @param info [Object] an object containing all info to apply to the player
		#
		initialize: ( @id, info = null, timestamp = null ) ->		
			@mass = 100
			@drag = .01
			@angularDrag = 7
			@applyGravity = true

			@flyLeft = 0
			@flyRight = 0
			@flyForward = 0
			@flyBackward = 0

			@boost = false
			@landed = false
			@landedPosition = new Three.Vector3()
			@baseExtended = false

			@_cannonReady = true

			@_ufoBase = new Three.Mesh()

			@_loader.load('/meshes/ufo.js', ( geometry, material ) =>
				geometry.computeBoundingSphere()

				# Set up skinned geometry mesh.
				@mesh = new Three.SkinnedMesh(geometry, new Three.MeshFaceMaterial(material))
				@mesh.receiveShadow = true
				material.skinning = true for material in @mesh.material.materials

				# Set up animations for the mesh.
				Three.AnimationHandler.add(@mesh.geometry.animation)
				@animation = new Three.Animation(@mesh, 'ArmatureAction', Three.AnimationHandler.CATMULLROM)
				@animation.play()

				# Create our cannon.
				@cannon = new Cannon(@world, @owner, @)

				# Apply passed info.
				@applyInfo(info)

				# Set the rotation of the player to be level with relation to the planet.
				levelRotation = @calculateLevelRotation().clone()
				levelRotationQuaternion = new Three.Quaternion().setFromEuler(levelRotation)

				rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)
				rotationQuaternion.multiply(levelRotationQuaternion)

				@rotation.setFromQuaternion(rotationQuaternion)
				@rotation.order = 'YXZ'

				# Add the mesh to the scene and set loaded state.
				@scene.add(@mesh)

				@_loader.load('/meshes/ufoBase.js', ( geometry, material ) =>
					@_ufoBase.geometry = geometry
					@_ufoBase.material = new Three.MeshFaceMaterial(material)
					@mesh.add(@_ufoBase)

					@loaded = true
				)
			)

			# Add listeners to common events.
			@on('impact.world', @_onImpactWorld)

		# Updates the physics state of the player. Adds forces to simulate gravity and 
		# the propulsion system. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			unless @loaded
				return

			rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)

			# Check if the player is within landing range of the planet. If she is,
			# retract the cannon, extend the landing gear, and set the ufo to attract
			# to a level position with relation to the normal of the surface below it.
			if intersect = @world.planet.getIntersect(@position, 1, 3)
				if intersect.distance < 2
					@cannon.extended = false
					surfaceNormal = intersect.face.normal
				else
					@cannon.extended = true
					surfaceNormal = @position
				@baseExtended = true
			else
				@baseExtended = false
				@cannon.extended = true
				surfaceNormal = @position

				# Add tilt forces
				@addAngularForce(new Three.Euler(0, 0, -30 * @flyForward * dt, 'YXZ'))
				@addAngularForce(new Three.Euler(0, 0, 30 * @flyBackward * dt, 'YXZ'))
				@addAngularForce(new Three.Euler(-30 * @flyLeft * dt, 0, 0, 'YXZ'))
				@addAngularForce(new Three.Euler(30 * @flyRight * dt, 0, 0, 'YXZ'))

			# Attract player to a straight position with relation to the planet surface.
			# The normal is determined in the previous step: when the player's close to
			# the surface, the normal will be calculated from the surface normal. Else,
			# the normal will be perpendicular to the planet sphere.
			levelRotation = @calculateLevelRotation(surfaceNormal)
			levelRotationQuaternion = new Three.Quaternion().setFromEuler(levelRotation)

			forceQuaternion = rotationQuaternion.clone().inverse().multiply(levelRotationQuaternion)
			force = new Three.Euler().setFromQuaternion(forceQuaternion)
			@addAngularForce(force)

			# Add thrust straight downward from the player. If the player's boosting,
			# the thrust will be significantly higher than then she's not.
			thrustVector = new Three.Vector3(0, 1, 0).applyQuaternion(rotationQuaternion)

			if @boost
				@landed = false
				thrustVector.multiplyScalar(19 * @mass * dt)
			else
				thrustVector.multiplyScalar(3 * @mass * dt)

			if @position.length() > 1000
				thrustVector.divideScalar(@position.length() - 1000)

			@addForce(thrustVector)
			
			# Update physics.
			super(dt, not @landed)

			# Update our cannon.
			@cannon.update(dt)

			# Update visuals.
			@_updateVisuals(dt)

		# Updates visuals that have nothing to do with physics, such as lowering
		# the base and updating the animation.
		#
		_updateVisuals: ( dt ) =>
			# Make the ufo bounce upward a bit when landed.
			if @landed
				targetPosition = @landedPosition.clone().add(@landedPosition.clone().setLength(.8))
				@position.lerp(targetPosition, dt * 8)

			# Retract or extend the base.
			if @baseExtended
				@_ufoBase.position.lerp(new Three.Vector3(0, 0, 0), dt * 8)
				@_ufoBase.scale.lerp(new Three.Vector3(1, 2, 1), dt * 8)
			else
				@_ufoBase.position.lerp(new Three.Vector3(0, .8, 0), dt * 5)
				@_ufoBase.scale.lerp(new Three.Vector3(1, .5, 1), dt * 5)

				@addAngularForce(new Three.Euler(0, @cannon.rotation.y * 20 * dt, 0, 'YXZ'))
				@cannon.addAngularForce(new Three.Euler(0, -@cannon.rotation.y * 20 * dt, 0, 'YXZ'))

			# Update alien animation.
			@animation.update(dt)

		# Fires a projectile when the cannon is ready, which is a fixed amount of time
		# after the last shot.
		#
		fire: ( ) ->
			if @_cannonReady and @cannon.extended

				projectile = new Projectile(@world, @owner, @, @cannon)
				@trigger('fire', projectile)
				@_cannonReady = false

				setTimeout( =>
					@_cannonReady = true
				, 500)

		# Calculates a level rotation with relation to the planet surface and returns
		# an euler representation of this rotation.
		#
		# @param vector [Three.Vector3] the normal vector.
		# @return [Three.Euler] the ideal (level) rotation.
		# 
		calculateLevelRotation: ( vector = @position ) ->
			upVector = vector.clone().normalize()
			rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)

			localZVector = new Three.Vector3(0, 0, -1).applyQuaternion(rotationQuaternion)
			localUpVector = localZVector.clone().projectOnVector(upVector)
			worldZVector = localZVector.clone().sub(localUpVector)

			rotationMatrix = new Three.Matrix4().lookAt(@position, worldZVector.add(@position), upVector)

			levelRotation = new Three.Euler().setFromRotationMatrix(rotationMatrix, 'YXZ')
			return levelRotation

		# Is called when the player impacts the world. Used to determine if the 
		# player should systain damage.
		#
		# @param position [Three.Vector3] the position of the player at the moment of impact
		# @param velocity [Three.Vector3] the velocity of the player at the moment of impact
		#
		_onImpactWorld: ( position, velocity ) ->
			downVelocity = velocity.projectOnVector(position)
			if downVelocity.length() > 30
				@die()
			else
				@landed = true
				@landedPosition = position

		# Applies information given in an object to the entity.
		#
		# @param info [Object] an object that contains the transformations
		#
		applyInfo: ( info, timestamp = null ) =>
			unless info
				return

			super(info, timestamp)
			
			if info.flyLeft?
				@flyLeft = info.flyLeft

			if info.flyRight?
				@flyRight = info.flyRight

			if info.flyForward?
				@flyForward = info.flyForward

			if info.flyBackward?
				@flyBackward = info.flyBackward

			if info.boost?
				@boost = info.boost

			if info.landed?
				@landed = info.landed

			if info.landedPosition?
				@landedPosition = @landedPosition.fromArray(info.landedPosition)

			if info.baseExtended?
				@baseExtended = info.baseExtended

			@cannon.applyInfo(info.cannon, timestamp)
			
		# Returns the current info in an object.
		#
		# @return [Object] an object of all the info
		#
		getInfo: ( ) ->
			info = super()

			info.flyLeft = @flyLeft
			info.flyRight = @flyRight
			info.flyForward = @flyForward
			info.flyBackward = @flyBackward

			info.boost = @boost
			info.landed = @landed
			info.landedPosition = @landedPosition.toArray()
			info.baseExtended = @baseExtended

			info.cannon = @cannon?.getInfo()

			return info
