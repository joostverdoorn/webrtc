# Browser-based multiplayer gaming using WebRTC

[Backlog] (https://github.com/joostverdoorn/webrtc/issues?milestone=none&amp;page=1&amp;state=open)

[Sprintlog] (https://github.com/joostverdoorn/webrtc/issues/milestones)

[Scrumboard] (http://huboard.com/joostverdoorn/webrtc/board)

Master branch is updated weekly, and is the result of that week's work.
Master version can be always found here:
[http://webrtc.jstfy.com](http://webrtc.jstfy.com)

To start a new node in network:
[http://webrtc.jstfy.com/node.html](http://webrtc.jstfy.com/node.html)

To view a graph of all nodes:
[http://webrtc.jstfy.com/nodegraph.html](http://webrtc.jstfy.com/nodegraph.html)

# Build
## Requirements
* NodeJS 0.10.x
* CoffeeScript 1.6.3

##Initial Build
`cake deploy`

##Subsequent builds
`cake build`

##Cleaning
`cake clean`

##Watch for changes
To automatically build the project when a file is changed `cake watch` can be used. This is useful when actively developing to prevent the constant execution of `cake build`.

##Running
`node lib/server.js`

This starts a listenserver on `localhost:8080` which responds to `index.html` for the game, `node.html` for a node that connects to other nodes and `nodegraph.html` for a visualization of the networktopology.

##Tests
`cake test`

This executes all tests and shows the output in the console. For the test-coverage a listenserver on `localhost:8081` is launched which visualizes the covered codelines.
