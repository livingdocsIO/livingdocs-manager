# Livingdocs Manager - ldm

## Installation

```
npm install -g livingdocs-manager
```

## Commands

Go into your design directory. Execute one of the following commands.

```bash
Usage: ldm <command>

where: <command> is one of:
    help                       Show this information
    version                    Show the cli version

    design:publish             Upload the design in the current directory
    design:build               Process the design in the current directory
    design:proxy               Start a design proxy server that caches designs

    project:design:add         Add a design to a project
    project:design:remove      Remove a design from a project
```


## Publish a design

```
cd ~/Development/livingdocs-design
ldm design:build ./src ./dist
ldm design:publish ./dist
```
