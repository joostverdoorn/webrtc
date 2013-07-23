define [
	'public/scripts/models/entity._'

	'three'
	], ( Entity, Three ) ->

	# This class implements projectile-specific properties for the entity physics object.
	#
	class Entity.Projectile extends Entity


		initialize: ( player = null, cannon = null ) ->
			@mass = 100
			@drag = .5
			@angularDrag = 1

			sphereMaterial = new Three.MeshLambertMaterial({ color: 0x008000 })
			radius = 0.4
			segments = 10
			rings = 20

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

			vector = new Three.Vector3(x, 0, z).multiplyScalar(150)
			vector.add(player.velocity)

			@addForce(vector)

			@scene.add(@mesh)

		update: ( dt ) ->
			# Gravity
			gravityVector = new Three.Vector3(0, -9.81, 0)
			@addForce(gravityVector)

			super(dt)

			@mesh.position = @position
			@mesh.rotation = @rotation
			

		die: ( ) ->
			@scene.remove(@mesh)


