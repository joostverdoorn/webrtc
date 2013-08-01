define [
	'public/scripts/models/entity._'
	'public/scripts/models/entity.cannon'
	'public/scripts/models/entity.projectile'

	'three'
	'jquery'
	], ( Entity, Cannon, Projectile, Three, $ ) ->

	# This class implements player-specific properties for the entity physics object.
	#
	class Entity.Player extends Entity

		# Is called from the baseclass' constructor. Will set up player specific 
		# properties for the entity
		#
		# @param id [String] the string id of the player
		# @param info [Object] an object containing all info to apply to the player
		#
		initialize: ( @id, info = null ) ->		
			@mass = 300
			@drag = .01
			@angularDrag = 7
			@applyGravity = true

			@flyLeft = 0
			@flyRight = 0
			@flyForward = 0
			@flyBackward = 0

			@boost = false
			@_cannonReady = true

			@_loader.load('/meshes/ufo.js', ( geometry, material ) =>
				geometry.computeBoundingSphere()

				# Set up skinned geometry mesh.
				@mesh = new Three.SkinnedMesh(geometry, new Three.MeshFaceMaterial(material))
				material.skinning = true for material in @mesh.material.materials

				# Set up animations for the mesh.
				Three.AnimationHandler.add(@mesh.geometry.animation)
				@animation = new Three.Animation(@mesh, 'ArmatureAction', Three.AnimationHandler.CATMULLROM)
				@animation.play()

				# Create our cannon.
				@cannon = new Cannon(@world, @owner, @)

				# Apply passed info.
				@applyInfo(info)

				# Set the rotation axis order to YXZ.
				@rotation.order = 'YXZ'

				# Add the mesh to the scene and set loaded state.
				@scene.add(@mesh)
				@loaded = true			
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

			# Add tilt forces
			@addAngularForce(new Three.Euler(-.6 * @flyLeft, 0, 0, 'YXZ'))
			@addAngularForce(new Three.Euler(.6 * @flyRight, 0, 0, 'YXZ'))
			@addAngularForce(new Three.Euler(0, 0, -.6 * @flyForward, 'YXZ'))
			@addAngularForce(new Three.Euler(0, 0, .6 * @flyBackward, 'YXZ'))

			# Add thrust straight downward from the player. 
			thrustVector = new Three.Vector3(0, 1, 0).applyQuaternion(rotationQuaternion)

			if @boost
				thrustVector.multiplyScalar(19 * @mass * dt)
			else
				thrustVector.multiplyScalar(3 * @mass * dt)

			if @position.length() > 1000
				thrustVector.divideScalar(@position.length() - 1000)

			@addForce(thrustVector)
			
			# Attract player to a straight position with relation to the planet surface.
			levelRotation = @calculateLevelRotation()
			levelRotationQuaternion = new Three.Quaternion().setFromEuler(levelRotation)

			forceQuaternion = rotationQuaternion.clone().inverse().multiply(levelRotationQuaternion)
			force = new Three.Euler().setFromQuaternion(forceQuaternion)
			@addAngularForce(force)

			# Attract player y rotation to cannon y rotation
			@addAngularForce(new Three.Euler(0, @cannon.rotation.y * 20 * dt, 0, 'YXZ'))
			@cannon.addAngularForce(new Three.Euler(0, -@cannon.rotation.y * 20 * dt, 0, 'YXZ'))

			# Update physics.
			super(dt)

			# Update our cannon.
			@cannon.update(dt)

			# Update alien animation.
			@animation.update(dt)

		# Fires a projectile.
		#
		fire: ( ) ->
			if @_cannonReady

				projectile = new Projectile(@world, @owner, @, @cannon)
				projectile.update(0)
				@trigger('fire', projectile)
				@_cannonReady = false

				setTimeout( =>
					@_cannonReady = true
				, 500)

		# Calculates a level rotation with relation to the planet surface and returns
		# an euler representation of this rotation.
		#
		# @return [Three.Euler] the ideal (level) rotation.
		# 
		calculateLevelRotation: ( ) ->
			upVector = @position.clone().normalize()
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
			if downVelocity.length() > 20
				@die()

		# Applies information given in an object to the entity.
		#
		# @param info [Object] an object that contains the transformations
		#
		applyInfo: ( info ) =>
			unless info
				return

			super(info)

			@boost = info.boost
			
			@flyLeft = info.flyLeft
			@flyRight = info.flyRight
			@flyForward = info.flyForward
			@flyBackward = info.flyBackward		

			@cannon.applyInfo(info.cannon)
			
		# Returns the current info in an object.
		#
		# @return [Object] an object of all the info
		#
		getInfo: ( ) ->
			info = super()
			
			info.boost = @boost

			info.flyLeft = @flyLeft
			info.flyRight = @flyRight
			info.flyForward = @flyForward
			info.flyBackward = @flyBackward			

			info.cannon = @cannon?.getInfo()

			return info
