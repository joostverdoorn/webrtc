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

			describe 'when getting a peer', ->
				fakePeer1 = fakePeer2 = null
				beforeEach ->
					fakePeer1 = {
						id: '1'
						role: 'a'
						isConnected: -> true
					}
					fakePeer2 = {
						id: '2'
						role: 'b'
						isConnected: -> false
					}

				it 'should find a peer by id', ->
					spyOn(node, 'getPeers').andReturn([
							fakePeer1
							fakePeer2
						])
					expect(node.getPeer('1')).toBe(fakePeer1)
					expect(node.getPeer('2')).toBe(fakePeer2)

				it 'should filter on role and connection status', ->
					spyOn(node, 'getPeers').andReturn([])
					expect(node.getPeer('1', 'a', false)).toBe(undefined)
					expect(node.getPeers.mostRecentCall.args).toEqual([
							'a'
							false
						])

			describe 'when getting peers', ->
				fakePeer1 = fakePeer2 = null
				beforeEach ->
					fakePeer1 = {
						id: '1'
						role: 'a'
						isConnected: -> true
					}
					fakePeer2 = {
						id: '2'
						role: 'b'
						isConnected: -> false
					}
					node._peers.push(fakePeer1, fakePeer2)

				it 'should return a filtered list of peers', ->
					expect(node.getPeers()).toEqual([
							fakePeer1
						])
					expect(node.getPeers('a')).toEqual([
							fakePeer1
						])
					expect(node.getPeers(null, true)).toEqual([
							fakePeer1
							fakePeer2
						])

			describe 'when receiving a message', ->
				it 'should start listening for the given event on all peers', ->
					spyOn(node._peers, 'on').andCallThrough()
					callback = ( args... ) ->
						expect(@).toBe(node)
						expect(args).toEqual([
								'2'
								'4'
								'3'
							])

					node.onReceive('test', callback)
					callArgs = node._peers.on.mostRecentCall.args
					expect(callArgs[0]).toBe('test')

					fakeMessage = {
							timestamp: '3'
						}
					callArgs[1]('1', '2', '4', fakeMessage)

				it 'should start listening for multiple events on all peers', ->
					originalReceive = node.onReceive
					spyOn(node, 'onReceive')

					callback1 = ->
						true
					callback2 = ->
						false
					originalReceive.call(node, {
							'test1': callback1
							'test2': callback2
						})

					expect(node.onReceive.calls[0].args).toEqual([
							'test1'
							callback1
						])
					expect(node.onReceive.calls[1].args).toEqual([
							'test2'
							callback2
						])

			describe 'when emitting a message', ->
				it 'should create Message object with given parameters', ->
					spyOn(node, 'relay')
					spyOn(node, 'time').andReturn('7')
					node.emitTo('1', '2', '3', '4', '5', '6')

					args = node.relay.mostRecentCall.args[0]

					expect(JSON.stringify(args)).toEqual(JSON.stringify({
							to: '1'
							from: node.id
							event: '2'
							args: [
								'3'
								'4'
								'5'
								'6'
							]
							timestamp: '7'
							_hash: args._hash
						}))		# JSON.stringify used because of weirdness with Jasmine

			describe 'when querying', ->
				it 'should start a listener on _peers for the query result', ->
					spyOn(node._peers, 'once')

					callback = ->
					node.queryTo('1', '2', callback, '3', '4')

					callArgs = node._peers.once.mostRecentCall.args
					expect(callArgs[1]).toEqual(callback)

				it 'should emit the query', ->
					spyOn(node, 'emitTo')
					spyOn(node._peers, 'once')

					callback = ->
					node.queryTo('1', '2', callback, '3', '4')

					callArgs = node._peers.once.mostRecentCall.args
					#expect(callArgs[1]).toEqual(callback)
					expect(node.emitTo.mostRecentCall.args).toEqual([
							'1'
							'query'
							'2'
							callArgs[0]
							'3'
							'4'
						])

			describe 'when broadcasting', ->
				it 'should emitTo *', ->
				it 'should create Message object with given parameters', ->
					spyOn(node, 'emitTo')
					node.broadcast('1', '2', '3')

					args = node.emitTo.mostRecentCall.args

					expect(args).toEqual([
							'*'
							'1'
							'2'
							'3'
						])

			describe 'when relaying', ->
				fakePeer1 = fakePeer2 = null
				beforeEach ->
					fakePeer1 = {
						send: jasmine.createSpy()
					}
					fakePeer2 = {
						send: jasmine.createSpy()
					}

				it 'should send to all peers when recipient is *', ->
					spyOn(node, 'getPeers').andReturn([
							fakePeer1
							fakePeer2
						])	# returns *
					fakeMessage = {
						a: 'b'
						to: '*'
					}
					node.relay(fakeMessage)
					expect(fakePeer1.send.mostRecentCall.args).toEqual([
							fakeMessage
						])
					expect(fakePeer2.send.mostRecentCall.args).toEqual([
							fakeMessage
						])

				it 'should send to the correct peer if it is not *', ->
					spyOn(node, 'getPeer').andReturn(fakePeer1)
					fakeMessage = {
						a: 'b'
						to: '1'
					}
					node.relay(fakeMessage)
					expect(fakePeer1.send.mostRecentCall.args).toEqual([
							fakeMessage
						])
					node.getPeer.reset()
					node.getPeer.andReturn(null)
					expect(node.relay(fakeMessage)).toBe(undefined)

			describe 'when receiving a query', ->
				it 'should handle ping requests', ->
					spyOn(node, 'time').andReturn(123)

					callback = ( event, time ) ->
						expect(event).toBe('pong')
						expect(time).toBe(123)

					node.query('ping', callback)

				it 'should handle type requests', ->
					callback = ( type ) ->
						expect(type).toBe(node.type)

					node.query('type', callback)

				it 'should handle info requests', ->
					peers = [
							{
								id: '1'
								role: '2'
							}
							{
								id: '3'
								role: '4'
							}
						]
					spyOn(node, 'getPeers').andReturn(peers)
					callback = ( info ) ->
						expect(info).toEqual({
								id: node.id
								type: node.type
								peers: peers
							})

					node.query('info', callback)

				it 'should handle random requests', ->
					callback = ( data... ) ->
						expect(data).toEqual([
								null
							])

					node.query(undefined, callback)

			describe 'when a peer wants to connect', ->
				it 'should connect to that peer', ->
					spyOn(node, 'connect')

					node._onPeerConnectionRequest('1')

					expect(node.connect.mostRecentCall.args).toEqual([
							'1'
							false
						])

			describe 'when connected with server', ->
				it 'should set own id to the one from the server', ->
					spyOn(node.server, 'ping')
					node._onServerConnect('1')
					expect(node.id).toBe('1')

				it 'should calculate the latency to the server', ->
					spyOn(node.server, 'ping')
					node._onServerConnect('1')

					# bad approach, might fail sometimes
					now = Date.now()
					delta = node.server.ping.mostRecentCall.args[0](100, 300)
					# formula should be: serverTime - (currentLocalTime - latency / 2)
					expect(node._timeDelta).toBe(delta)
					expect(delta).toEqual(300 - (now - 50))
