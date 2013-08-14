define [
	'public/scripts/models/entity._'
	'public/scripts/models/entity.cannon'
	'public/scripts/models/entity.projectile'
	'public/scripts/models/stats'

	'three'
	], ( Entity, Cannon, Projectile, Stats, Three ) ->

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
			@stats = new Stats()
			@stats.addStat('kills')
			@stats.addStat('deaths')

			@mass = 100
			@drag = .01
			@angularDrag = 7
			@applyGravity = true

			@flyLeft = 0
			@flyRight = 0
			@flyForward = 0
			@flyBackward = 0

			@boost = 0
			@landed = false
			@landedPosition = new Three.Vector3()
			@baseExtended = false

			@_cannonReady = true

			# Add listeners to common events.
			@on
				'loaded': =>
					@_onLoaded()
					@applyInfo(info)
				'impact.world': @_onImpactWorld

			# Load meshes.
			if Player.Model? then @trigger('loaded')
			else
				Entity.Loader.load '/meshes/ufo.js', ( geometry, material ) =>
					Player.Model = {}

					# Setup geometry.
					Player.Model.Geometry = geometry
					Player.Model.Geometry.computeBoundingSphere()
					Three.AnimationHandler.add(Player.Model.Geometry.animation)

					# Setup materials.
					Player.Model.Material = new Three.MeshFaceMaterial(material)
					material.skinning = true for material in Player.Model.Material.materials

					# Setup mesh.
					Player.Model.Mesh = new Three.SkinnedMesh(Player.Model.Geometry, Player.Model.Material)
					Player.Model.Mesh.receiveShadow = true

					# Setup base.
					Entity.Loader.load '/meshes/ufoBase.js', ( geometry, material ) =>
						Player.Model.Base = {}

						Player.Model.Base.Geometry = geometry
						Player.Model.Base.Material = new Three.MeshFaceMaterial(material)
						Player.Model.Base.Mesh = new Three.Mesh(Player.Model.Base.Geometry, Player.Model.Base.Material)

						@trigger('loaded')

		# Updates the physics state of the player. Adds forces to simulate gravity and
		# the propulsion system. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt, ownPlayer ) ->
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
			thrustVector.multiplyScalar(@mass * (3 + @boost * 16) * dt)

			if @position.length() > 1000
				thrustVector.divideScalar(@position.length() - 1000)

			@addForce(thrustVector)

			if @boost then @landed = false

			# Update physics.
			super(dt, ownPlayer, not @landed)

			# Update our cannon.
			@cannon.update(dt, ownPlayer)

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
				@_ufoBaseMesh.position.lerp(new Three.Vector3(0, 0, 0), dt * 8)
				@_ufoBaseMesh.scale.lerp(new Three.Vector3(1, 2, 1), dt * 8)
			else
				@_ufoBaseMesh.position.lerp(new Three.Vector3(0, .8, 0), dt * 5)
				@_ufoBaseMesh.scale.lerp(new Three.Vector3(1, .5, 1), dt * 5)

				@addAngularForce(new Three.Euler(0, @cannon.rotation.y * 20 * dt, 0, 'YXZ'))
				@cannon.addAngularForce(new Three.Euler(0, -@cannon.rotation.y * 20 * dt, 0, 'YXZ'))

			# Update alien animation.
			@animation.update(dt)

		# Fires a projectile when the cannon is ready, which is a fixed amount of time
		# after the last shot.
		#
		fire: ( ) ->
			if @_cannonReady and @cannon.extended

				projectile = new Projectile(@world, @ownerID, @owner, @, @cannon)
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

		_onLoaded: ( ) =>
			@loaded = true

			# Setup UFO
			@mesh = Player.Model.Mesh.clone()
			@scene.add(@mesh)

			@animation = new Three.Animation(@mesh, 'ArmatureAction', Three.AnimationHandler.CATMULLROM)
			@animation.play()

			# Setup UFO base
			@_ufoBaseMesh = Player.Model.Base.Mesh.clone()
			@mesh.add(@_ufoBaseMesh)

			# Create the cannon.
			@cannon = new Cannon(@world, @ownerID, @owner, @)

			# Set the rotation of the player to be level with relation to the planet.
			levelRotation = @calculateLevelRotation().clone()
			levelRotationQuaternion = new Three.Quaternion().setFromEuler(levelRotation)

			rotationQuaternion = new Three.Quaternion().setFromEuler(@rotation)
			rotationQuaternion.multiply(levelRotationQuaternion)

			@rotation.setFromQuaternion(rotationQuaternion)
			@rotation.order = 'YXZ'

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
				@world.trigger('player.kill', @)
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

			@cannon?.applyInfo(info.cannon, timestamp)

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
