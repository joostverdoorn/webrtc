require.config
	paths:
		'public': '../../public'

require [
	'public/library/../library/models/remote.peer'
	'public/library/models/message'
	], ( Peer, Message ) ->

	describe 'Remote.Peer', ->

		peer = null
		fakeController = null

		# Fake RTCPeerConnection object to prevent actually connecting with something
		fakeRTC = null

		class global.FakeRTCDataChannel
			onmessage: ->
			onopen: ->
			onclose: ->
			onmessage: ->
			send: ->

		class global.FakeRTCPeerConnection
			@iceConnectionState: null

			constructor: ->

			onicecandidate: ->
			oniceconnectionstatechange: ->
			ondatachannel: ->
				new FakeRTCDataChannel()

			createDataChannel: ->
				new FakeRTCDataChannel()
			createOffer: ->
			close: ->
			setLocalDescription: ->
			setRemoteDescription: ->
			createAnswer: ->
			addIceCandidate: ->

		class FakeController

			class FakeServer
				emitTo: ->
			
			constructor: ->		
				@server = new FakeServer()

			id: '2'
			query: ->
			relay: ->

		beforeEach ->

			fakeController = new FakeController()

		describe 'when initialized', ->
			it 'should create a new RTCPeerConnection object with default configurations', ->
				# Jasmine will remove the original prototype so we need to restore it later
				originalPrototype = FakeRTCPeerConnection.prototype
				constructorSpy = spyOn(global, 'FakeRTCPeerConnection').andCallThrough()
				FakeRTCPeerConnection.prototype = originalPrototype

				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				expect(constructorSpy).toHaveBeenCalled()

				callArgs = FakeRTCPeerConnection.mostRecentCall.args
				expect(callArgs.length).toBe(2)
				expect(callArgs[0]).toEqual(Peer.prototype._serverConfiguration)
				expect(callArgs[1]).toEqual(Peer.prototype._connectionConfiguration)

				expect(peer._connection.onicecandidate).toEqual(peer._onIceCandidate)
				expect(peer._connection.oniceconnectionstatechange).toEqual(peer._onIceConnectionStateChange)
				expect(peer._connection.ondatachannel).toEqual(peer._onDataChannel)

			it 'should listen on all RTC connection events', ->
				spyOn(Peer.prototype, '_onConnect')
				spyOn(Peer.prototype, '_onDisconnect')
				spyOn(Peer.prototype, '_onChannelOpened')
				spyOn(Peer.prototype, '_onChannelClosed')
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)

				peer.trigger('connect')
				peer.trigger('disconnect')
				peer.trigger('channel.opened')
				peer.trigger('channel.closed')

				expect(peer._onConnect).toHaveBeenCalled()
				expect(peer._onDisconnect).toHaveBeenCalled()
				expect(peer._onChannelOpened).toHaveBeenCalled()
				expect(peer._onChannelClosed).toHaveBeenCalled()

			it 'should instantiate the Vivaldi parameters correctly', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)

				expect(peer.latency).toBe(0)
				expect(peer.coordinates.length).toBe(3)
				expect(peer.coordinates[0]).toBe(0)
				expect(peer.coordinates[1]).toBe(0)
				expect(peer.coordinates[2]).toBe(0)

			it 'should actually start a connection (or not) depending on the instantiate parameter', ->
				spyOn(Peer.prototype, 'connect')
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				expect(peer.connect).toHaveBeenCalled()

				Peer.prototype.connect.reset()
				peer = new Peer(fakeController, '1', false, FakeRTCPeerConnection)
				expect(peer.connect).not.toHaveBeenCalled()

		describe 'when connecting', ->
			it 'should be a "connector"', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				expect(peer._isConnector).toBe(true)

			it 'should tell the server about the connection request', ->
				spyOn(fakeController.server, 'emitTo')
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)

				expect(fakeController.server.emitTo).toHaveBeenCalled()

				callArgs = fakeController.server.emitTo.mostRecentCall.args
				expect(callArgs.length).toBe(4)
				expect(callArgs[0]).toBe('1')
				expect(callArgs[1]).toBe('peer.connectionRequest')
				expect(callArgs[2]).toBe(fakeController.id)
				expect(callArgs[3]).toBe(undefined)		# old type identifier, currently unused but not yet removed

			it 'should create a data channel', ->
				peer = new Peer(fakeController, '1', false, FakeRTCPeerConnection)
				spyOn(peer._connection, 'createDataChannel').andCallThrough()

				peer.connect()

				expect(peer._connection.createDataChannel).toHaveBeenCalled()
				callArgs = peer._connection.createDataChannel.mostRecentCall.args
				expect(callArgs.length).toBe(2)
				expect(callArgs[0]).toBe('a')
				expect(callArgs[1]).toBe(Peer.prototype._channelConfiguration)

			it 'should assign the created channel to itself', ->
				peer = new Peer(fakeController, '1', false, FakeRTCPeerConnection)

				fakeChannel = new FakeRTCDataChannel()
				spyOn(peer._connection, 'createDataChannel').andReturn(fakeChannel)
				spyOn(peer, '_addChannel')

				peer.connect()

				expect(peer._addChannel).toHaveBeenCalled()
				callArgs = peer._addChannel.mostRecentCall.args
				expect(callArgs.length).toBe(1)
				expect(callArgs[0]).toEqual(fakeChannel)

		describe 'when disconnecting', ->
			it 'should close the RTCPeerConnection', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(peer._connection, 'close')

				peer.disconnect()

				expect(peer._connection.close).toHaveBeenCalled()

		describe 'when sending', ->
			it 'should check if the channel is open before sending', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(peer, 'isChannelOpen').andReturn(false)
				spyOn(peer._channel, 'send')

				result = peer._send('a')

				expect(peer.isChannelOpen).toHaveBeenCalled()
				expect(peer._channel.send).not.toHaveBeenCalled()
				expect(result).toBe(false)

			it 'should send the message when the connection works', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(peer, 'isChannelOpen').andReturn(true)
				spyOn(peer._channel, 'send')

				message = new Message('a', 'b', 'event')
				
				result = peer._send(message)

				expect(result).toBe(true)

			it 'should try to send the message multiple times when there are errors', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(peer, 'isChannelOpen').andReturn(true)
				spyOn(peer._channel, 'send')
				spyOn(peer, '_send').andCallThrough()
				
				result = peer._send(null)

				expect(result).toBe(undefined)
				# _send will asynchronous recall itself so we had to spy on it above and now wait for the fail count to rise to 6 (initial call + 5 retries)
				waitsFor(->
						return peer._send.callCount is 6
					, 1000)
		
		describe 'when adding a channel', ->
			it 'should set _channel to the channel', ->
				peer = new Peer(fakeController, '1', false, FakeRTCPeerConnection)
				fakeChannel = new FakeRTCDataChannel()
				peer._addChannel(fakeChannel)

				expect(peer._channel).toEqual(fakeChannel)

			it 'should set the channels events to its own callbacks', ->
				peer = new Peer(fakeController, '1', false, FakeRTCPeerConnection)
				fakeChannel = new FakeRTCDataChannel()
				peer._addChannel(fakeChannel)

				expect(peer._channel.onmessage).toEqual(peer._onChannelMessage)
				expect(peer._channel.onopen).toEqual(peer._onChannelOpen)
				expect(peer._channel.onclose).toEqual(peer._onChannelClose)
				expect(peer._channel.onerror).toEqual(peer._onChannelError)

		describe 'when a local description is created', ->
			it 'should be sent to the remote node via the central server', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(peer._connection, 'setLocalDescription')
				spyOn(fakeController.server, 'emitTo')

				peer._onLocalDescription('a')

				expect(peer._connection.setLocalDescription).toHaveBeenCalled()

				callArgs = peer._connection.setLocalDescription.mostRecentCall.args
				expect(callArgs.length).toBe(1)
				expect(callArgs[0]).toBe('a')

				expect(fakeController.server.emitTo).toHaveBeenCalled()

				callArgs = fakeController.server.emitTo.mostRecentCall.args
				expect(callArgs.length).toBe(4)
				expect(callArgs[0]).toBe('1')
				expect(callArgs[1]).toBe('peer.setRemoteDescription')
				expect(callArgs[2]).toBe(fakeController.id)
				expect(callArgs[3]).toBe('a')

		describe 'when setting a remote description', ->
			it 'should set the remote description for RTC connection', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(peer._connection, 'setRemoteDescription')

				peer.setRemoteDescription('a')

				expect(peer._connection.setRemoteDescription).toHaveBeenCalled()
				callArgs = peer._connection.setRemoteDescription.mostRecentCall.args
				expect(callArgs.length).toBe(1)
				expect(callArgs[0]).toBe('a')

			it 'should create an answer if we are not the connector', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(peer._connection, 'createAnswer')
				peer._isConnector = true

				peer.setRemoteDescription('a')

				expect(peer._connection.createAnswer).not.toHaveBeenCalled()

				peer._isConnector = false

				peer.setRemoteDescription('a')

				expect(peer._connection.createAnswer).toHaveBeenCalled()
				callArgs = peer._connection.createAnswer.mostRecentCall.args
				expect(callArgs.length).toBe(3)
				expect(callArgs[0]).toEqual(peer._onLocalDescription)
				expect(callArgs[1]).toBe(null)
				expect(callArgs[2]).toEqual({})

		describe 'when receiving an ICE candidate', ->
			it 'should ignore it if there is not actally no candidate', ->
				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(fakeController.server, 'emitTo')

				peer._onIceCandidate({})

				expect(fakeController.server.emitTo).not.toHaveBeenCalled()

			it 'should send valid candidates to the central server'
				fakeCandidate = 'asghlbasv8og348iwb viosu'

				peer = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				spyOn(fakeController.server, 'emitTo')

				peer._onIceCandidate({
						candidate: fakeCandidate
					})

				expect(fakeController.server.emitTo).toHaveBeenCalled()
				callArgs = fakeController.server.emitTo.mostRecentCall.args
				expect(callArgs.length).toBe(4)
				expect(callArgs[0]).toBe('1')
				expect(callArgs[0]).toBe('peer.addIceCandidate')
				expect(callArgs[0]).toBe(fakeController.id)
				expect(callArgs[0]).toBe(fakeCandidate)
