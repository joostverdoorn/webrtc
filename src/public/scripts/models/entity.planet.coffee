define [
	'public/scripts/models/entity._'
	'public/scripts/models/entity.cannon'
	'public/scripts/models/entity.projectile'

	'three'
	], ( Entity, Cannon, Projectile, Three ) ->

	# This class implements player-specific properties for the entity physics object.
	#
	class Entity.Planet extends Entity

		# Is called from the baseclass' constructor. Will set up player specific 
		# properties for the entity
		#
		# @param id [String] the string id of the player
		# @param info [Object] an object containing all info to apply to the player
		#
		initialize: ( ) ->		
			@mass = 1000000000
			@applyGravity = false

			@_loader.load('/meshes/planet.js', ( geometry, material ) =>
				geometry.computeBoundingSphere()
				geometry.computeMorphNormals()

				@mesh.geometry = geometry
				@mesh.material = new Three.MeshFaceMaterial(material)

				# Add the mesh to the scene and set loaded state.
				@scene.add(@mesh)
				@loaded = true
			)