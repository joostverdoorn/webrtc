require.config
	baseUrl: '../../../../'
	paths:
		'public/library/models/remote.server': 'tests/mock/remote.server.mock'
		'public/library/models/remote.peer': 'tests/mock/remote.peer.mock'
		
require [
	'public/library/node'
	'public/library/models/vector'
	'public/library/models/collection'

	], ( Node, Vector, Collection ) ->
		describe 'Node', ->

			node = null
			peer = null
			
			beforeEach ->
				node = new Node()

			afterEach ->
				node.removeIntervals()

			describe 'when created', ->

				it 'should not be a supernode', ->
					expect(node.isSuperNode).toBeFalsy()

				it 'should an empty Collection of peers', ->
					expect(node._peers.length).toBe(0)
					expect(node._peers instanceof Collection ).toBeTruthy()

				it 'should have Vector coordinates', ->
					expect(node.coordinates instanceof Vector ).toBeTruthy()

			describe 'when connect and disconnect to other nodes', ->

				beforeEach ->
					peer = node.connect("123456")

				it 'should add peer to a Peer collection', ->
					expect(node._peers.length).toBe(1)
					expect(node.getPeers().length).toBe(1)
					expect(node.getPeer("123456")).toBe(peer)

				it 'should remove peer from a Peer collection', ->
					node.disconnect(peer.id)
					expect(node._peers.length).toBe(0)

			describe 'when entering network', ->

				beforeEach ->
					node._enterNetwork()

				it 'should connect to a superNode if a superNode is available', ->
					expect(node._peers.length).toBe(1)
					expect(node.isSuperNode).toBeFalsy()