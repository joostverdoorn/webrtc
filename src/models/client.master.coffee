Client = require('./client._')

# This class is a server side representation of a master client
#

class Client.Master extends Client
	initialize: ( attributes, options ) ->
		console.log 'new master'

module.exports = Client.Master