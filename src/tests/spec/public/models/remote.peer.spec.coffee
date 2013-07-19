require.config
	paths:
		'public': '../../public'

require [
	'public/library/models/remote.peer'
	], ( Peer ) ->

	describe 'Remote.Peer', ->

		remote = null
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

				remote = new Peer(fakeController, '1', true, FakeRTCPeerConnection)
				expect(constructorSpy).toHaveBeenCalled()

				callArgs = FakeRTCPeerConnection.mostRecentCall.args
				expect(callArgs.length).toBe(2)
				expect(callArgs[0]).toEqual(Peer.prototype._serverConfiguration)
				expect(callArgs[1]).toEqual(Peer.prototype._connectionConfiguration)

				expect(remote._connection.onicecandidate).toEqual(remote._onIceCandidate)
				expect(remote._connection.oniceconnectionstatechange).toEqual(remote._onIceConnectionStateChange)
				expect(remote._connection.ondatachannel).toEqual(remote._onDataChannel)

			it 'should listen on all RTC connection events', ->
				remote = new Peer(fakeController, '1', true, FakeRTCPeerConnection)

				console.log(remote._onConnect.toString())
				spyOn(remote, '_onConnect')
				spyOn(remote, '_onDisconnect')
				spyOn(remote, '_onChannelOpened')
				spyOn(remote, '_onChannelClosed')

				console.log(remote._onConnect.toString())
				remote.trigger('connect')
				remote.trigger('disconnect')
				remote.trigger('channel.opened')
				remote.trigger('channel.closed')

				expect(remote._onConnect).toHaveBeenCalled()
				expect(remote._onDisconnect).toHaveBeenCalled()
				expect(remote._onChannelOpened).toHaveBeenCalled()
				expect(remote._onChannelClosed).toHaveBeenCalled()