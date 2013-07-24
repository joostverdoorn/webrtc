define [
	'public/scripts/models/entity._'

	'three'
	], ( Entity, Three ) ->

	# This class implements projectile-specific properties for the entity physics object.
	#
	class Entity.Projectile extends Entity


		initialize: ( player = null, cannon = null ) ->
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

			@position = cannon.position.clone()
			@position.y -= 0.9

			x = Math.cos(cannon.rotation.y)
			z = -Math.sin(cannon.rotation.y)

			vector = new Three.Vector3(x, 0, z).multiplyScalar(250)
			vector.add(player.velocity)

			@addForce(vector)

			@scene.add(@mesh)

		update: ( dt ) ->
			super(dt)

		die: ( ) ->
			@scene.remove(@mesh)


