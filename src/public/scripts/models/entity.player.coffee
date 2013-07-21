define [
	'public/scripts/models/entity._'

	'three'
	], ( Entity, Three ) ->

	# 
	class Entity.Player extends Entity

		initialize: ( callback ) ->
			@_loader.load('/meshes/ufo.js', ( geometry, material ) =>
				@mesh = new Three.Mesh(geometry, new THREE.MeshFaceMaterial(material))
				callback?()
			)

		update: ( dt ) ->
			super(dt)

			@mesh.rotation.x += .004
			@mesh.rotation.y += .003
			@mesh.rotation.z += .005
			@mesh.position.x += .001

