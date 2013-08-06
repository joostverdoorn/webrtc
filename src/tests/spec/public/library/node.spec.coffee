require.config
	baseUrl: '../../../../'
	paths:
		'public/library/models/remote.server': 'tests/mock/remote.server.mock'
		'public/library/models/remote.peer': 'tests/mock/remote.peer.mock'
		
require [
	'public//library/node'
	'public//library/models/collection'
	'public/library/models/remote.peer'
	], ( Node, Collection, Peer ) ->
		describe 'Node', ->
			node = null
			peer = null
			
			beforeEach ->
				node = new Node()

			describe 'when created', ->
				it 'should create a new Remote.Server and register several callbacks on it', ->
					expect(node.server._mockTriggers.splice(-4, 4)).toEqual([
							'connect'
							'peer.connectionRequest'
							'peer.setRemoteDescription'
							'peer.addIceCandidate'
						])
				it 'should create a new _peers Collection', ->
					expect(node._peers.length).toBe(0)
					spyOn(node, 'removePeer')
					node._peers.trigger('disconnect', 'a')
					expect(node.removePeer.mostRecentCall.args).toEqual([
							'a'
						])

			describe 'when connecting', ->
				it 'should create a new peer and add it', ->
					spyOn(node, 'addPeer')
					peer = node.connect('1', true)
					expect(peer._controller).toBe(node)
					expect(peer.id).toBe('1')
					expect(peer.instantiate).toBe(true)
					expect(node.addPeer.mostRecentCall.args).toEqual([
							peer
						])

			describe 'when disconnecting', ->
				it 'should disconnect an existing peer', ->
					fakePeer = {
						disconnect: jasmine.createSpy()
					}
					spyOn(node, 'getPeer').andReturn(fakePeer)
					node.disconnect('1')
					expect(node.getPeer.mostRecentCall.args).toEqual([
							'1'
						])
					expect(fakePeer.disconnect).toHaveBeenCalled()
					node.getPeer.reset()
					node.getPeer.andReturn(null)
					expect(node.disconnect('2')).toBe(undefined)

			describe 'when adding a peer', ->
				it 'should add the peer to _peers', ->
					node.addPeer('1')
					expect(node._peers.length).toBe(1)
					expect(node._peers[0]).toEqual('1')

				it 'should trigger a peer.added event', ->
					node.on('peer.added', ( peer ) ->
							expect(peer).toBe('1')
						)
					node.addPeer('1')

			describe 'when removing a peer', ->
				peer = null
				beforeEach ->
					peer = {
						die: jasmine.createSpy()
					}
					node.addPeer(peer)

				it 'should kill the peer', ->
					node.removePeer(peer)
					expect(peer.die).toHaveBeenCalled()

				it 'should remove the peer from _peers', ->
					node.removePeer(peer)
					expect(node._peers.length).toBe(0)

				it 'should trigger a peer.remove event', ->
					node.on('peer.removed', ( thePeer ) ->
							expect(thePeer).toBe(peer)
						)
					node.removePeer(peer)