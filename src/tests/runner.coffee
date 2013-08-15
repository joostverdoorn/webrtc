jasmine = require 'jasmine-node'

jsc = require './tools/jscoverage-reporter/src/jasmine.jscoverage_reporter.js'
jasmineEnv = jasmine.getEnv()
jasmineEnv.addReporter(new jsc('./reports'))

jasmine.executeSpecsInFolder
	specFolders: [__dirname + '/spec']
	isVerbose: true
	showColors: true
	useRequireJs: true
	done: ( runner, log ) ->
		jasmineEnv.execute()
		if runner.results().failedCount == 0
			process.exit 0
		else
			process.exit 1
