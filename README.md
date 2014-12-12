# Pasha

![Smart Router](doc/pasha.jpg)

Pasha is a chat bot that is designed to help us during Prio1s with relaying iformation, improving communication and executing certain tasks. It is a Hubot mod and it was mainly inspired by Gitub's Chat Ops.

##Usage
Pasha sits in some HipChat channels and listens for commands. You can issue a command by typing in 'pasha <command>'.

You can get help with 'pasha help'. This displays the full list of commands and their usage and you also can get specific help by typing 'pasha <command> help'.

###Modules
Pasha is designed to be modular and extensible. It has a main module with minimal functionality and modules to extend it.

####Main Module
The main module of pasha is capable of creating and managing Prio1 situations: you can start, confirm and stop Prio1s and assign Prio1 leader and communications role to people.

#####Commands
Initiate a Prio1 situation (works only if there is no Prio1 currently going on):
       
    pasha prio1 start <problem>
    e.g. pasha prio1 start There is a network outage between Rackspace and EC2

Confirm a Prio1 (works only if there is a started Prio1):

    pasha prio1 confirm


Stop a Prio1 (works only if there is a Prio1 going on):

    pasha prio1 stop

Assign Prio1 leader role to a person (works only if there is a Prio1 going on):

    pasha role leader <name>
    e.g. pasha role leader elvis

Assign Prio1 communications role to a person (works only if there is a Prio1 going on):

    pasha role comm <name>
    e.g. pasha role comm elvis

Get info about a person:

    pasha whois <name>
    e.g. pasha whois elvis

####Changelog Module
This module makes Pasha capable of sending events to [Changelog](https://changelog.prezi.com) and query it for revent events.

#####Commands
Query Changelog for recent changes:

    pasha changelog <int>[smhd]
    e.g. pasha changelog 25m
 	
Send events to Changelog:

    pasha changelog add <event>
    e.g. pasha changelog add Elvis restarted HAProxy on lb5

##Development
Hubot and thus Pasha is written in [CoffeeScript](http://coffeescript.org/). Pasha is nothing else but a stripped Hubot loaded with some custom scripts.

Pasha is designed to be easily extensible. It's modules work the same way as Hubot modules work: you put a coofeescript file into a certain directory and the next time you start Hubot your script will be loaded.

###Setting up the Development Environment

####Redis
You will need redis for Pasha's brain (the in-memory storage). Although Hubot is capable of running without a redis server listening (on the default port 6379) in production it uses redis, so you will get a behavior that is more close to the production env if you install redis.

On a Mac it should be as easy as

    brew install redis
(this installs redis-2.6.16 for me)

To run redis just type

    redis-server
    
in a terminal window. Please note that you need to have redis-server running in a terminal while in another one you are running Pasha. Of course you can run redis-server in the background as a daemon.

####Node
Hubot (and thus Pasha) is a Cooffeescript application (which at the end of the day gets comipled to Javascript) that runs in the Node.js Javascript engine.

On a Mac it should be as easy as

    brew install node
(this installs node-0.10.25 and npm for me)

####Node Modules
Pasha has a `package.json` file in it's root directory. This contains the list of Node packages that are required to run it locally.

After checking out the project from Git you can install the required npm packages by issueing the following command in Pasha's root directory

    npm install

###Running Locally
You can check out this GitHub repository and run locally without problems.

You need a Redis server to be able to use the Redis Brain module of Hubot.

Run with an interactive bash adapter from Pasha's root dir: `./run_scripts/run_bash_adapter.sh`

Run with a HipChat adapter from Pasha's root dir: `./run_scripts/run_hipchat_adapter.sh`

###Configuration
Pasha tries to load a configuration file from `/etc/prezi/pasha/pasha.cfg` to load credentials and be able to connect to HipChat and other services that need authentication.

###Testing
Pasha does have tests. Awesome. You can run the tests with `./run_scripts/run_tests.sh`

If you write a new module please write tests for it. Thanks.
###Deployment
Pasha is built and deployed through [Docker](https://www.docker.com/).

###Monitoring
Pasha has very basic monitoring, there is a monitoring check that goes to HipChat and checks whether Pasha is present on the `pasha_monitoring` HipChat channel or not.

##Resources
   * [Hubot](https://hubot.github.com/)
   * [Hubot Scripting](https://github.com/github/hubot/blob/master/docs/scripting.md)
   * [Chat Ops](https://www.youtube.com/watch?v=NST3u-GjjFw)
   * [Changelog](https://changelog.prezi.com)
   * [CoffeeScript](http://coffeescript.org/)
   * [Docker](https://www.docker.com/)