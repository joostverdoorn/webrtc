_ = require('underscore')._
Backbone = require('backbone')

# This abstract class provides websocket connections for masters and slaves
#

class Client
	constructor: ( @socket, attributes, options ) ->
		@defaults = _.extend({}, @_defaults, @defaults ? {})

		@initialize(attributes, options)

module.exports = Client