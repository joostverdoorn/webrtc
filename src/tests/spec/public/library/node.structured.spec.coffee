#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
###
require.config
	baseUrl: '../../../../'
	paths:
		'public/library/models/remote.server': 'tests/mock/remote.server.mock'
		'public/library/models/remote.peer': 'tests/mock/remote.peer.mock'

require [
	'public/library/node.structured'
	'public/library/models/vector'
	'public/library/models/collection'
	'public/library/models/remote.peer'

	], ( Node, Vector, Collection, Peer ) ->
		describe 'Node.Structured', ->

			node = null
			peer = null

			beforeEach ->
				node = new Node()

			afterEach ->
				node.removeIntervals()

			describe 'when created', ->

				it 'should not be a supernode', ->
					expect(node.isSuperNode).toBeFalsy()

				it 'should have an empty Collection of peers', ->
					expect(node._peers.length).toBe(0)
					expect(node._peers instanceof Collection ).toBeTruthy()

				it 'should have Vector coordinates', ->
					expect(node.coordinates instanceof Vector ).toBeTruthy()

			describe 'when connect and disconnect to other nodes', ->
				beforeEach ->
					spyOn(node, 'removePeer').andCallThrough()
					spyOn(node, 'addPeer').andCallThrough()
					peer = node.connect("123456")

				it 'should add peer to a Peer collection', ->
					expect(node.addPeer).toHaveBeenCalled()
					expect(node.addPeer.mostRecentCall.args[0] instanceof Peer).toBe(true)
					expect(node._peers.length).toBe(1)
					expect(node.getPeers().length).toBe(1)
					expect(node.getPeer("123456")).toBe(peer)

				it 'should remove peer from a Peer collection', ->
					node.disconnect(peer.id)
					expect(node._peers.length).toBe(0)

			describe 'when event based disconnect occurs', ->
				beforeEach ->
					spyOn(node, 'removePeer')
					spyOn(node, 'getParent')
					peer = node.connect("123456")

				it 'should call the callback when the peer disconnects', ->
					node.getParent.andReturn(false)
					peer.trigger('disconnect')
					expect(node.getParent).toHaveBeenCalled()
					expect(node.removePeer).toHaveBeenCalled()
					expect(node.removePeer.mostRecentCall.args).toEqual([
							peer
						])

				it 'should pick a new parent if disconnecting node is parent', ->
					node.getParent.andReturn(peer)
					spyOn(node, 'getPeers').andReturn([
							{
								isSuperNode: false
							}
							{
								isSuperNode: false
							}
							{
								isSuperNode: false
							}
							{
								a: 1
								isSuperNode: true
							}
						])
					spyOn(node, '_pickParent')
					peer.trigger('disconnect')
					expect(node.getParent).toHaveBeenCalled()
					expect(node.getPeers).toHaveBeenCalled()
					expect(node._pickParent).toHaveBeenCalled()
					expect(node._pickParent.mostRecentCall.args).toEqual([
							[
								{
									a: 1
									isSuperNode: true
								}
							]
						])
					expect(node.removePeer).toHaveBeenCalled()
					expect(node.removePeer.mostRecentCall.args).toEqual([
							peer
						])


				it 'should trigger the _triggerStaySuperNodeTimeout()', ->
					spyOn(node, '_triggerStaySuperNodeTimeout')
					peer.trigger('disconnect')
					expect(node._triggerStaySuperNodeTimeout).toHaveBeenCalled()

			describe 'when adding a peer', ->
				it 'should get added to the internal list', ->
					fakePeer = {
						a: 1
						b: 2
					}
					spyOn(node._peers, 'add')
					node.addPeer(fakePeer)
					expect(node._peers.add.mostRecentCall.args).toEqual([
							fakePeer
						])

				it 'should trigger the peer.added event', ->
					fakePeer = {
						a: 1
						b: 2
					}
					success = false
					node.on('peer.added', ( peer ) ->
							success = true
						)
					node.addPeer(fakePeer)
					waitsFor(->
							return success
						, 1000)

			describe 'when removing a peer', ->
				fakePeer = null

				beforeEach ->
					fakePeer = {
						a: 1
						b: 2
						die: ->
					}

				it 'should get killed first', ->
					fakePeer.die = jasmine.createSpy('die')
					node.removePeer(fakePeer)
					expect(fakePeer.die).toHaveBeenCalled()

				it 'should get removed from the internal list', ->
					spyOn(node._peers, 'remove')
					node.removePeer(fakePeer)
					expect(node._peers.remove.mostRecentCall.args).toEqual([
							fakePeer
						])

				it 'should trigger the peer.removed event', ->
					success = false
					node.on('peer.removed', ( peer ) ->
							success = true
						)
					node.removePeer(fakePeer)
					waitsFor(->
							return success
						, 1000)

			describe 'when entering network', ->

				beforeEach ->
					node._enterNetwork()

				it 'should connect to a superNode if a superNode is available', ->
					expect(node._peers.length).toBe(1)
					expect(node.isSuperNode).toBeFalsy()

			describe 'when pinging', ->
				it 'should set an interval to ping given peer', ->
					jasmine.Clock.useMock();
					fakePeer = {
						ping: jasmine.createSpy()
					}
					node.ping(fakePeer)
					expect(fakePeer.pingInterval).not.toBe(undefined)
					expect(fakePeer.ping).not.toHaveBeenCalled()
					jasmine.Clock.tick(501)
					expect(fakePeer.ping.callCount).toBe(1)
###
