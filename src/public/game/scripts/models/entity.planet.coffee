define [
	'game/scripts/models/entity._'
	'game/scripts/models/entity.cannon'
	'game/scripts/models/entity.projectile'

	'three'
	], ( Entity, Cannon, Projectile, Three ) ->

	# This class implements player-specific properties for the entity physics object.
	#
	class Entity.Planet extends Entity

		vertexShaderAtmosphere: "
			uniform vec3 viewVector;
			uniform float c;
			uniform float p;
			varying float intensity;
			void main()
			{
			    vec3 vNormal = normalize( normalMatrix * normal );
				vec3 vNormel = normalize( normalMatrix * viewVector );
				intensity = pow( c - dot(vNormal, vNormel), p );

			    gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
			}"

		fragmentShaderAtmosphere: "
			uniform vec3 glowColor;
			uniform float glowOpacity;
			varying float intensity;
			void main()
			{
				vec3 glow = glowColor * intensity;
			    gl_FragColor = vec4( glow, glowOpacity );
			}"

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
				Entity.Loader.load '/game/meshes/planet.js', ( geometry, material ) =>
					Planet.Model = {}

					Planet.Model.Geometry = geometry
					Planet.Model.Geometry.computeBoundingSphere()
					Planet.Model.Geometry.computeMorphNormals()

					Planet.Model.Material = new Three.MeshFaceMaterial(material)

					Planet.Model.Mesh = new Three.Mesh(Planet.Model.Geometry, Planet.Model.Material)
					Planet.Model.Mesh.castShadow = true

					@trigger('loaded')

		# Update the planets atmospheric properties
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt ) ->
			if App?.camera?
				# Gruadually decrease inner atmosphere density.
				if App.player?
					if App.player.position.length() > 500
					 	opacity = 0
					else if App.player.position.length() < 300
						opacity = 1
					else
						opacity = Math.pow(1 - (App.player.position.length() - 300) / 200, 2)

					@innerAtmosphere?.material.uniforms.glowOpacity.value = opacity

				# Set the correct camera position for the atmosphere.
				@innerAtmosphere?.material.uniforms.viewVector.value = App.camera.position
				@outerAtmosphere?.material.uniforms.viewVector.value = App.camera.position

		# Triggers when the Planet Mesh is fully loaded
		#
		# @private
		#
		_onLoaded: ( ) =>
			@loaded = true

			@mesh = Planet.Model.Mesh.clone()
			@scene.add(@mesh)

			if App?.camera?
				# Create outer atmosphere visible from a greater distance to the planet.
				atmosphereGeometry = new Three.SphereGeometry(510, 32, 32)
				atmosphereMaterial = new THREE.ShaderMaterial
					uniforms:
						c:   { type: "f", value: .8 },
						p:   { type: "f", value: 3 },
						glowColor: { type: "c", value: new THREE.Color(0x444fff) },
						glowOpacity: { type: "f", value: 1}
						viewVector: { type: "v3", value: App.camera.position }
					vertexShader:   @vertexShaderAtmosphere
					fragmentShader: @fragmentShaderAtmosphere
					side: THREE.BackSide,
					blending: THREE.AdditiveBlending,
					transparent: true
					depthWrite: false

				@outerAtmosphere = new Three.Mesh(atmosphereGeometry, atmosphereMaterial)
				@mesh.add(@outerAtmosphere)

				# Create inner atmosphere to simulate blue skies when close to the planet.
				atmosphereGeometry = new Three.SphereGeometry(500, 32, 32)
				atmosphereMaterial = new THREE.ShaderMaterial
					uniforms:
						c:   { type: "f", value: .1 },
						p:   { type: "f", value: .5 },
						glowColor: { type: "c", value: new THREE.Color(0x444fff) },
						glowOpacity: { type: "f", value: 0}
						viewVector: { type: "v3", value: App.camera.position }
					vertexShader:   @vertexShaderAtmosphere
					fragmentShader: @fragmentShaderAtmosphere
					side: THREE.BackSide,
					blending: THREE.AdditiveBlending,
					transparent: true
					depthWrite: false

				@innerAtmosphere = new Three.Mesh(atmosphereGeometry, atmosphereMaterial)
				@mesh.add(@innerAtmosphere)
