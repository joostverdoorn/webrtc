define [
	'public/scripts/models/entity._'
	'public/scripts/models/entity.cannon'
	'public/scripts/models/entity.projectile'

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
			varying float intensity;
			void main()
			{
				vec3 glow = glowColor * intensity;
			    gl_FragColor = vec4( glow, 1.0 );
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
				Entity.Loader.load '/meshes/planet.js', ( geometry, material ) =>
					Planet.Model = {}

					Planet.Model.Geometry = geometry
					Planet.Model.Geometry.computeBoundingSphere()
					Planet.Model.Geometry.computeMorphNormals()

					Planet.Model.Material = new Three.MeshFaceMaterial(material)

					Planet.Model.Mesh = new Three.Mesh(Planet.Model.Geometry, Planet.Model.Material)
					Planet.Model.Mesh.castShadow = true

					@trigger('loaded')

		update: ( dt ) ->
			if App.camera.position.length() > 400
				@atmosphere?.material.uniforms.c.value = .8
			else if App.camera.position.length() < 300
				@atmosphere?.material.uniforms.c.value = 0
			else
				@atmosphere?.material.uniforms.c.value = (App.camera.position.length() - 300) / 100 * .8
				#@atmosphere?.material.uniforms.c.value = (App.camera.position.length() - 400) / 400
			#console.log @atmosphere?.material.uniforms.c.value
			#@atmosphere?.material.uniforms.viewVector.value = new THREE.Vector3().subVectors(App.camera.position, @atmosphere.position)
			@atmosphere?.material.uniforms.viewVector.value = new THREE.Vector3().subVectors(App.camera.position, @atmosphere.position)

		_onLoaded: ( ) =>
			@loaded = true

			@mesh = Planet.Model.Mesh.clone()
			@scene.add(@mesh)

			atmosphereGeometry = new Three.SphereGeometry(400, 40, 40)
			atmosphereMaterial = new THREE.ShaderMaterial
				uniforms:
					c:   { type: "f", value: .8 },
					p:   { type: "f", value: 3 },
					glowColor: { type: "c", value: new THREE.Color(0x444fff) },
					viewVector: { type: "v3", value: App.camera.position }
				vertexShader:   @vertexShaderAtmosphere
				fragmentShader: @fragmentShaderAtmosphere
				side: THREE.BackSide,
				blending: THREE.AdditiveBlending,
				transparent: true

			@atmosphere = new Three.Mesh(atmosphereGeometry, atmosphereMaterial)
			@scene.add(@atmosphere)
			########################3


			# atmosphereGeometry = new Three.SphereGeometry(400, 40, 40)
			# atmosphereMaterial = new THREE.ShaderMaterial
			# 	uniforms:
			# 		c:   { type: "f", value: 0 },
			# 		p:   { type: "f", value: 6 },
			# 		glowColor: { type: "c", value: new THREE.Color(0x444fff) },
			# 		viewVector: { type: "v3", value: App.camera.position }
			# 	vertexShader:   @vertexShaderAtmosphere
			# 	fragmentShader: @fragmentShaderAtmosphere
			# 	side: THREE.BackSide,
			# 	blending: THREE.AdditiveBlending,
			# 	transparent: true

			# @atmosphere2 = new Three.Mesh(atmosphereGeometry, atmosphereMaterial)
			# @scene.add(@atmosphere2)
