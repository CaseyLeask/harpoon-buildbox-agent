# harpoon-buildbox-agent

A [Docker](http://docker.io/) and [harpoon](http://harpoon.sh/) enabled version of the [Buildbox agent](https://github.com/buildbox/buildbox-agent) which runs each CI job in its own set of Docker containers. Just add a `harpoon.yml` to each project (see [the postgres example app](https://github.com/toolmantim/harpoon-ci-test-app)) and you'll have completely isolated testing with a custom environment for every build job.

![2 tests in parallel](https://cloud.githubusercontent.com/assets/153/4101405/5cc2f4ce-30e8-11e4-9ebd-d27898c1fdcf.gif)

Each project can define as many containers as it needs (e.g. Ruby, Postgres, Redis, etc) using the standard [harpoon.yml conharpoon syntax](http://www.harpoon.sh/yml.html). Before a build step is run, harpoon builds and links all the required containers, and then destroys them afterwards. All you need to do is make sure your project has a harpoon.yml file.

The Docker containers are namespaced to each build job (rather than Docker-in-Docker style), so you get the benefit of per-job isolation but with fast build and start times thanks to Docker's cache. And you're free to run as many side-by-side buildbox agents as you wish. This is 20 agents on a 20 CPU Digital Ocean droplet:

![20 agents](https://cloud.githubusercontent.com/assets/153/4101420/0948c688-30e9-11e4-8900-b904fa82515e.png)

*How does it work?* It uses a [customised bootstrap.sh](bootstrap.harpoon.sh#L59) file which calls harpoon before and after the build script is run.

## Installation

### Using the Docker image

There is a [buildbox/agent Docker image](https://registry.hub.docker.com/u/buildbox/agent/) which you can use, which has baked in harpoon support..

Just run the `buildbox/agent` image, which Docker will automatically pull from the Docker Registry, and start it up passing in your Buildbox account's agent token, and passing your local Docker socket through to the image (so it can call Docker from within the container). Giving it a name allows you to inspect it, tail the logs, etc.

```bash
# Start the agent
docker run -e BUILDBOX_AGENT_TOKEN=abc123 -v /var/run/docker.sock:/var/run/docker.sock --name bb-agent-1 buildbox/agent

# Tail the logs
docker logs -f bb-agent-1
```

You can start multiple build agents by adding the `-d` argument, which will cause docker to boot the agent in the background.

```bash
# Start multiple agents
export BUILDBOX_AGENT_TOKEN=abc123
docker run -d -e $BUILDBOX_AGENT_TOKEN -v /var/run/docker.sock:/var/run/docker.sock buildbox/agent
docker run -d -e $BUILDBOX_AGENT_TOKEN -v /var/run/docker.sock:/var/run/docker.sock buildbox/agent
docker run -d -e $BUILDBOX_AGENT_TOKEN -v /var/run/docker.sock:/var/run/docker.sock buildbox/agent
```

### From source, using harpoon

This repository defines it's own harpoon.yml file and can be started inside a Docker using harpoon (this starts 2 agents for a 2 CPU machine):

```bash
$ git clone https://github.com/toolmantim/harpoon-buildbox-agent.git
$ cd harpoon-buildbox-agent
$ env BUILDBOX_AGENT_TOKEN=abc123 harpoon scale agent=2 && harpoon logs
...
Starting harpoonbuildboxagent_agent_1...
Starting harpoonbuildboxagent_agent_2...
Attaching to harpoonbuildboxagent_agent_2, harpoonbuildboxagent_agent_1
agent_2 | 2014-08-30 15:34:36 [INFO ] Registering agent (name:  hostname: 8bff65bc5094 meta-data: [harpoon])
agent_2 | 2014-08-30 15:34:39 [INFO ] Started agent `8bff65bc5094` (pid: 1 version: 1.0-beta.1)
agent_1 | 2014-08-30 15:34:36 [INFO ] Registering agent (hostname: 5cd0389ccd95 meta-data: [harpoon] name: )
agent_1 | 2014-08-30 15:34:39 [INFO ] Started agent `5cd0389ccd95` (version: 1.0-beta.1 pid: 1)
agent_1 | 2014-08-30 15:35:43 [INFO ] Starting job d5feb2f5-7ee3-44eb-8999-91b58d0f4a7b
agent_2 | 2014-08-30 15:35:44 [INFO ] Starting job 916200f4-57f8-435b-831b-6def4d413b7f
agent_2 | 2014-08-30 15:35:45 [INFO ] Starting to run script: /.buildbox/bootstrap.harpoon.sh
agent_2 | 2014-08-30 15:35:45 [INFO ] Process is running with PID: 16
agent_1 | 2014-08-30 15:35:45 [INFO ] Starting to run script: /.buildbox/bootstrap.harpoon.sh
agent_1 | 2014-08-30 15:35:45 [INFO ] Process is running with PID: 16
agent_1 | 2014-08-30 15:36:14 [INFO ] Finished job d5feb2f5-7ee3-44eb-8999-91b58d0f4a7b
agent_2 | 2014-08-30 15:36:14 [INFO ] Finished job 916200f4-57f8-435b-831b-6def4d413b7f
^C
Aborting.
$ harpoon stop
Stopping harpoonbuildboxagent_agent_2...
Stopping harpoonbuildboxagent_agent_1...
```

### From source, outside of Docker

You don't have to run the build agent itself inside of Docker, but it does need harpoon and Docker to be installed and available.

Follow these steps to set it up yourself:

* Install harpoon and Docker.
* Install buildbox-agent [as per usual](https://github.com/buildbox/buildbox-agent).
* Copy [bootstrap.harpoon.sh](bootstrap.harpoon.sh) to the buildbox agent directory (usually `/home/buildbox/.buildbox/` if you installed it as the buildbox user).
* Start your buildbox agents with `--bootstrap-script /home/buildbox/.buildbox/bootstrap.harpoon.sh`

## Setting up your projects

### Adding the harpoon.yml

Every app must have a `harpoon.yml` with an `app` container. The app container is where the agent will to run your build scripts inside of (using `harpoon run app <build-script>`).

See the [harpoon-ci-test-app](https://github.com/toolmantim/harpoon-ci-test-app) for an example yml that creates an `app` and a `db` container:

```yml
app:
  build: .
  links:
    - db
db:
  image: postgres
```

You can also see the [harpoon documentation](http://harpoon.sh/) for all the options available in your harpoon.yml, as well as example conharpoonurations for various languages and frameworks.

### Conharpoonuring your Buildbox project's build pipeline

* Set your build steps as normal. They'll be executed relative to your `app` container's working directory.
* The agent starts with the metadata `harpoon=true` so you can easily target harpoon-enabled agents in your build pipeline.
