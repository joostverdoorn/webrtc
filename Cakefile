exec = require('child_process').exec;
spawn = require('child_process').spawn
os = require('os')
fs = require('fs')

sourceDir = 'src'
targetDir = 'lib'
noKeep = [targetDir, 'node_modules', 'doc', 'reports']

# Installs all dependencies and builds all files
#
task 'deploy', ->
	deploy()

# Builds all files and copies everything into root directory
#
task 'build', ->
	build()

# Runs the server
#
task 'run', ->
	startProcess('node lib/server')

# Clears root directory of all built files
#
task 'clean', ->
	clean()

# Watches for file changes and compiles accordingly
#
task 'watch', ->
	watch()

# Runs the spec tests
#
task 'test', ->
	test()

# Starts a new process by executing the execString, and 
# logs all stdout and stderr output.
#
# @param processString [String] the string to execute
# @param out [Function] the function that should be called on all stdout
# @param err [Function] the function that should be called on all stderr
# @return [Process] the process
#
startProcess = ( execString, callback ) ->
	ps = exec(execString, callback)

	ps.stdout.setEncoding('utf8')
	ps.stderr.setEncoding('utf8')

	ps.stdout.on('data', ( data ) ->
		console.log(data)
	)

	ps.stderr.on('data', ( data ) ->
		console.log(data)
	)

# Deploys the application by cleaning, building and installing all dependencies
#
deploy = ( ) ->
	startProcess('npm install', ( err ) ->
		unless err
			build()
	)
	

# Builds application
#
build = ( ) ->
	buildCoffee()
	buildOthers()

# Compiles all coffeescripts to the target directory
#
buildCoffee = ( ) ->
	startProcess("coffee -mco ./#{targetDir} ./#{sourceDir}", ( err ) ->
		unless err
			log "compiled coffeescripts"
	)

# Copies all files not built by the coffee utility to the target directory
#
buildOthers = ( ) ->
	fs = require('fs-extra')
	walk(sourceDir, ( err, files ) ->
		if files
			files.forEach( ( file ) ->
				split = file.split('.')
				if split[split.length - 1] is 'coffee'
					return

				target = file.replace(sourceDir, targetDir)
				copy(file ,target)
			)
	)

# Watches the source tree for changes and updates the target directory accordingly
#
watch = ( ) ->
	retries = 0
	try
		fs = require('fs-extra')
		watchTree = require('fs-watch-tree').watchTree

		startProcess("coffee -mwco ./#{targetDir} ./#{sourceDir}")
		buildOthers()
		
		watchTree(sourceDir, ( event ) ->
			retries = 0
			file = event.name
			
			split = file.split('.')
			if split[split.length - 1] is 'coffee'
				return
				
			target = file.replace(sourceDir, targetDir)
			if event.isDelete()
				fs.remove(target, ( err ) ->
					unless err
						log "removed #{target}"
				)

			else 
				if not event.isDirectory()
					copy(file, target)

				if event.isMkdir()
					fs.mkdirs(target, ( err ) ->
						unless err
							log "created #{target}"
					)
		)
	catch
		if retries < 10
			watch()

# Removes all built files.
#
clean = ( ) ->
	fs = require('fs-extra')
	fs.readdir('./', ( err, list ) ->
		if err
			throw(err)

		list.forEach( ( file ) ->
			if file in noKeep
				fs.remove(file)
		)
	)

# Runs the test suite
#
test = ( ) ->
	fs.mkdir('reports', ->
		startProcess('node ./node_modules/coffee-coverage/bin/coffeecoverage ./src ./lib --exclude node_modules,.git,tests --path relative', ->
			jsCoveragePath = 'src/tests/tools/jscoverage-reporter'

			#wrench.copyDirSyncRecursive(jsCoveragePath + '/template/', './reports/');
			startProcess('node lib/tests/runner', ->
				startProcess('node ' + jsCoveragePath + '/tools/report.js ./reports/')
			)
		)
	)

# Copies a file to the target. If the path doesn't exist,
# creates the path.
#
# @param file [String] the path to the source file
# @param target [String] the path to the target file
copy = ( file, target ) ->
	fs = require('fs-extra')

	if file.indexOf('.tmp') > -1
		return

	fs.mkdirs(target.split('/').slice(0, -1).join('/'), ( err ) ->
		unless err
			fs.copy(file, target, ( ) ->
				unless err
					log "created #{target}"
			)
	)

# Logs a message to the console, and prepends it with a timestamp
#
# @param message [String] the message to log
#
log = ( message ) ->
	date = new Date()
	console.log "#{date.toLocaleTimeString()} - #{message}"

# Traverses all directories, calls the callback when done with an array of files
#
# @param dir [String] the directory to traverse
# @param done [Function] the callback to call when done
#
walk = ( dir, done ) ->
	fs = require('fs-extra')
	results = []

	fs.readdir(dir, ( err, list ) ->
		if err
			throw(err)

		pending = list.length
		if pending is 0
			return done(null, results)

		list.forEach( ( file ) ->
			file = "#{dir}/#{file}"
			fs.stat(file, ( err, stat ) ->
				if stat and stat.isDirectory()
					walk(file, ( err, res ) ->
						results = results.concat(res)
						if --pending is 0
							done(null, results)
					)
				else
					results.push(file)
					if --pending is 0
						done(null, results)
			)
		)
	)
