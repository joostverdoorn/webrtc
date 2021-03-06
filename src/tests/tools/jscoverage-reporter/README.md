# jscoverage-reporter - JSCoverage Report for Jasmine

A [Jasmine](https://github.com/pivotal/jasmine) reporter that will capture code coverage metrics generated by [JSCoverage](http://siliconforks.com/jscoverage/). Works well with [jasmine-node](https://github.com/mhevery/jasmine-node) and [PhantomJS](http://www.phantomjs.org/).

At this point the reporter requires a little setup to use as it assumes you are already using jasmine-node for testing. A simple wrapper script described below makes it easy to add this reporter to an out of the box jasmine-node install.

# Installation
    npm install jscoverage-reporter

You will also need a version of JSCoverage installed to generate the covered files. My preference is to download and install from [http://siliconforks.com/jscoverage/](http://siliconforks.com/jscoverage/) as we also test non node.js code.

# Usage

## Core Syntax

    require('jscoverage-reporter');
    jasmine.getEnv().addReporter(new jasmine.JSCoverageReporter('./reports'));

## jasmine-node wrapper
Create a file called **coverage.js**:

    require('jasmine-node');
    require('jscoverage-reporter');
    var jasmineEnv = jasmine.getEnv();
    // Adjust output directory as needed
    jasmineEnv.addReporter(new jasmine.JSCoverageReporter('./reports'));
    require('./node_modules/jasmine-node/lib/jasmine-node/cli.js');

After running JSCoverage on the code to test:

    npm install jasmine-node
    node coverage.js <jasmine-node options>

## JSCoverage wrapper
To run a single command that executes JSCoverage and runs the tests, an example can be found at [tools/coverage.js](https://github.com/NeoPhi/jscoverage-reporter/blob/master/tools/coverage.js).

In `package.json` you can then define your test script as:

    "test": "node tools/coverage --junitreport build/test",


## Viewing the Report
Two files `jscoverage.json` and `coverage.xml` will be produced. The `jscoverage.json` file can be used with the modified JSCoverage [template](https://github.com/NeoPhi/jscoverage-reporter/tree/master/template) to view the coverage. As JSCoverage complains about file based paths, to view the data a simple node.js based HTTP report server can be found in [tools/report.js](https://github.com/NeoPhi/jscoverage-reporter/blob/master/tools/report.js). The `coverage.xml` is suitable for Emma report tracking such as with [Emma Jenkins Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Emma+Plugin).

----
Copyright (c) 2012 Daniel Rinehart. This software is licensed under the MIT License.
