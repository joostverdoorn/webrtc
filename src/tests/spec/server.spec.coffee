require.config
	baseUrl: '../../',
	paths:
		'public/library/models/remote.server': 'tests/mock/remote.server.mock'
		'public/library/models/remote.peer': 'tests/mock/remote.peer.mock'
		'public/library/models/remote.client': 'tests/mock/remote.client.mock'
		'express': 'tests/mock/express.mock'
		'http': 'tests/mock/http.mock'

require [
	'server'
	], ( Server ) ->
		describe 'Server', ->

			server = null
			
			describe 'when constructing', ->

				beforeEach ->
					server = new Server()

				describe 'logging in', ->
					it 'should create a new node with the server as controller and a socket as connection', ->
						
