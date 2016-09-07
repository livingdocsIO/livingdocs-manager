# Livingdocs Manager - ldm

A cli to manage designs and the configuration of a livingdocs server.

## Installation

```
npm install -g livingdocs-manager
```

## Commands

Go into your design directory. Execute one of the following commands.

```bash
$ ldm
Usage: ldm <command>

where: <command> is one of:

  help                              #  Show this information

  version                           #  Show the cli version

  user:info                         #  Prints the user information

  design:build                      #  Compile the design
  design:publish                    #  Show the script version
  design:proxy                      #  Start a design server that caches designs

  project:channel:list              #  List all designs of all channels of a project

  channel:design-version:add        #  Add a design version to a channel
  channel:design-version:remove     #  Remove a design version from a channel
  channel:design-version:current    #  Set a current design version as default of a channel
  channel:design-version:enable     #  Enable a design version of a channel
  channel:design-version:disable    #  Disable a design version of a channel
```


## Publish a design

```
cd ~/Development/livingdocs-design
ldm design:build ./src ./dist
ldm design:publish ./dist
```

### Force update an existing design
```
ldm design:publish ./dist --force
```


## To release a new version of this module

You can run
```
npm version [major|minor|patch]
```

