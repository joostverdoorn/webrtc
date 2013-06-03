express = require('express')
http = require('http')
io = require('socket.io')

Model = require('./models')

class Server

	constructor: ( ) ->
		@_initTime = Date.now()

		@_masters = []
		@_slaves = []

		@_app = express()
		@_server = http.createServer(@_app)
		@_io = io.listen(@_server)
		@_io.sockets.on('connection', @login)
		
		# Serve static content from ./public
		@_app.configure =>
			@_app.use(express.static("#{__dirname}/public"))
			
		@_server.listen(8080)

	login: ( socket ) =>
		socket.on('type.set', ( type ) => 
			switch type
				when 'master'
					@_masters.push(new Model.Client.Master(socket))
				when 'slave'
					@_slaves.push(new Model.Client.Slave(socket))
		)

	time: ( ) ->
		return Date.now() - @_initTime
		
module.exports = new Server()
