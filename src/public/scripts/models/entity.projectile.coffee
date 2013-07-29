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
		# @param transformations [Object] an object containing all transformations to apply to the player
		#
		initialize: ( player = null, cannon = null, transformations ) ->
			@mass = 10
			@drag = .0005
			@angularDrag = 10
			@applyGravity = true

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

			if cannon? and player?
				playerRotationQuaternion = new Three.Quaternion().setFromEuler(player.rotation)

				# Get the starting position of the projectile.
				offset = new Three.Vector3(0, -1.10, 0)
				offset.applyQuaternion(playerRotationQuaternion)
				@position = player.position.clone().add(offset)

				# Calculate the angle at which the projectile will be fired.
				x = Math.cos(cannon.rotation.y)
				z = -Math.sin(cannon.rotation.y)

				@force = new Three.Vector3(x * @mass, 0, z * @mass)
				@force.applyQuaternion(new Three.Quaternion().setFromEuler(player.rotation))
				@force.multiplyScalar(50)

				# Add the player velocity to the force.
				@force.add(player.velocity.clone().multiplyScalar(@mass))

				# Add the force to the pending forces
				@addForce(@force)

			# Add the projectile to the scene
			@scene.add(@mesh)
			@loaded = true

		# Removes projectile form the scene
		#
		die: ( ) ->
			@scene.remove(@mesh)