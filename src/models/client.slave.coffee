Client = require('./client._')

# This class is a server side representation of a slave client
#

class Client.Slave extends Client
	initialize: ( attributes, options ) ->
		console.log 'new slave'

module.exports = Client.Slave