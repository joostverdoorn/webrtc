define [
	'public/scripts/models/entity._'

	'three'
	], ( Entity, Three ) ->

	# This class implements the cannon hanging from the ufo
	#
	class Entity.Cannon extends Entity

		# Is called from the baseclass' constructor. 
		#
		# @param transformations [Object] an object containing all transformations to apply to the player
		#
		initialize: ( transformations = null ) ->
			@mass = 10
			@angularDrag = 3

			@applyTransformations(transformations)

			@_loader.load('/meshes/cannon.js', ( geometry, material ) =>
				@mesh.geometry = geometry
				@mesh.material = new Three.MeshFaceMaterial(material)				
				@scene.add(@mesh)
			)

		# Updates the physics state of the cannon. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			super(dt, false, true)

