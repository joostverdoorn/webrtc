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

			@on('loaded', @_onLoaded)

			if Planet.Model? then @trigger('loaded')
			else
				Entity.Loader.load '/meshes/planet.js', ( geometry, material ) =>
					Planet.Model = {}

					Planet.Model.Geometry = geometry
					Planet.Model.Geometry.computeBoundingSphere()
					Planet.Model.Geometry.computeMorphNormals()

					Planet.Model.Material = new Three.MeshFaceMaterial(material)

					Planet.Model.Mesh = new Three.Mesh(Planet.Model.Geometry, Planet.Model.Material)
					Planet.Model.Mesh.castShadow = true

					console.log @
					@trigger('loaded')

		_onLoaded: ( ) =>
			@loaded = true

			@mesh = Planet.Model.Mesh.clone()
			@scene.add(@mesh)

