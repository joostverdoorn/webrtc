define [
	'public/scripts/models/entity._'

	'three'
	], ( Entity, Three ) ->

	# This class implements projectile-specific properties for the entity physics object.
	#
	class Entity.Projectile extends Entity


		# Is called from the baseclass' constructor. Will set up projectile specific 
		# properties for the entity
		#
		# @param player [Player] Player who fires the projectile
		# @param cannon [Cannon] Cannon which fires the projectile
		# @param info [Object] an object containing all info to apply to the player
		#
		initialize: ( player = null, cannon = null, info = null ) ->
			@mass = 10
			@drag = .0005
			@angularDrag = 10
			@applyGravity = true

			@_projectileVelocity = 100

			sphereMaterial = new THREE.MeshPhongMaterial( {color:0xff0000 })
			radius = 0.45
			segments = 6
			rings = 8

			@mesh = new Three.Mesh(
				new Three.SphereGeometry(
					radius,
					segments,
					rings)
				, sphereMaterial)

			# If both cannon and player are defined, instantiate the projectile forces.
			if cannon? and player?
				# Get the starting position of the projectile.
				@position = cannon.position.clone()
				player.mesh.localToWorld(@position)

				# Generate the projectile force.
				@force = new Three.Vector3(@_projectileVelocity * @mass, 0, 0)

				# Apply the cannon rotation to the force vector.
				@force.applyQuaternion(new Three.Quaternion().setFromEuler(cannon.rotation))

				# Apply the player rotation to the force vector.
				@force.applyQuaternion(new Three.Quaternion().setFromEuler(player.rotation))

				# Add the player velocity to the force.
				@force.add(player.velocity.clone().multiplyScalar(@mass))

				# Add the force to the pending forces
				@addForce(@force)
				player.addForce(@force.clone().negate())
			else @applyInfo(info)

			# Add the projectile to the scene
			@scene.add(@mesh)
			@loaded = true

			# Add listeners to common events.
			@on('impact.world', @_onImpactWorld)

		# Is called when the projectile impacts the world.
		#
		# @param position [Three.Vector3] the position of the projectile at the moment of impact
		# @param velocity [Three.Vector3] the velocity of the projectile at the moment of impact
		#
		_onImpactWorld: ( position, velocity ) =>
			@die()
