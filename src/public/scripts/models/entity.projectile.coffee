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

			@position = @position.fromArray(cannon.position)
			@position.y -= 0.9




			x = Math.cos(cannon.rotation[1])
			z = -Math.sin(cannon.rotation[1])
			vector = new Three.Vector3(x, 0, z).multiplyScalar(25)
			@addForce(vector)

			@scene.add(@mesh)

		update: ( dt ) ->
			# Gravity
			gravityVector = new Three.Vector3(0, -1, 0)
			@addForce(gravityVector)

			super(dt)

			@mesh.position = @position
			@mesh.rotation = @rotation
			

		die: ( ) ->
			@scene.remove(@mesh)


