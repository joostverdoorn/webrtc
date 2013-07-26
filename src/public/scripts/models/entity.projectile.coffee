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
			@applyGravity = true

			sphereMaterial = new THREE.MeshBasicMaterial( {color:0x00ff00 * Math.random() }) 
			radius = 0.4
			segments = 6
			rings = 8

			@mesh = new Three.Mesh(
				new Three.SphereGeometry(
					radius,
					segments,
					rings)
				, sphereMaterial)

			if cannon? and player?
				@position = cannon.position.clone()
				@position.y -= 0.9

				x = Math.cos(cannon.rotation.y)
				z = -Math.sin(cannon.rotation.y)

				@vector = new Three.Vector3(x * @mass, 0, z * @mass).multiplyScalar(50)
				@vector.add(player.velocity.clone().multiplyScalar(@mass))
				@addForce(@vector)
			@scene.add(@mesh)

			@loaded = true

		# Removes projectile form the scene
		#
		die: ( ) ->
			@scene.remove(@mesh)