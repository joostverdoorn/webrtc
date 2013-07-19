require.config
	paths:
		'public': '../../public'

require [
	'public/library/models/remote.peer'
	], ( Peer ) ->

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

			id: '1'
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
