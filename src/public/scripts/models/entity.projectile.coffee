define [
	'public/scripts/models/entity._'

	'three'
	], ( Entity, Three ) ->

	# This class implements projectile-specific properties for the entity physics object.
	#
	class Entity.Projectile extends Entity


		initialize: ( player = null, cannon = null, transformations ) ->
			@mass = 10
			@drag = .0005
			@applyGravity = true

			sphereMaterial = new Three.MeshLambertMaterial({ color: 0x008000 })
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

				@vector = new Three.Vector3(x * @mass, 0, z * @mass).multiplyScalar(25)
				@vector.add(player.velocity.clone().multiplyScalar(@mass))
				@addForce(@vector)
			@scene.add(@mesh)

		update: ( dt ) ->
			super(dt)

		die: ( ) ->
			@scene.remove(@mesh)

		# Serializes this projectile to a JSON string
		#
		# @return [String] the JSON string representing this projectile
		#
		serialize: ( ) ->
			object = 
				position: @position.toArray()
				vector: @vector.toArray()
			return JSON.stringify(object)

		# Generates a projectile from a JSON string and returns this
		#
		# @param projectileString [String] a string in JSON format
		# @return [Projectile] a new Projectile
		#		
		@deserialize: ( projectileString, scene ) ->
			object = JSON.parse(projectileString)
			position = new Three.Vector3().fromArray(object.position)
			vector = new Three.Vector3().fromArray(object.vector)
			projectile = new Projectile(scene, null, null, position, vector)
			return projectile


