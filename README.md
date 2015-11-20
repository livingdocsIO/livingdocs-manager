# Livingdocs Manager - ldm

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

  help                          #  Show this information

  version                       #  Show the cli version

  user:info                     #  Prints the user information

  design:build                  #  Compile the design
  design:publish                #  Show the script version
  design:proxy                  #  Start a design server that caches designs

  project:design:list           #  List all designs of a project
  project:design:add            #  Add a design to a project
  project:design:remove         #  Remove a design from a project
  project:design:default        #  Set a design as default
  project:design:enable         #  Enable project's design
  project:design:disable        #  Disable project's design
```


## Publish a design

```
cd ~/Development/livingdocs-design
ldm design:build ./src ./dist
ldm design:publish ./dist
```
