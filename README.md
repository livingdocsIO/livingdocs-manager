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

  help:       Show this information
  version:    Show the cli version
  publish:    Upload the design in the current directory
  build:      Process the design in the current directory
```


## Publish a design

```
cd ~/Development/livingdocs-design
ldm design:build ./src ./dist
ldm design:publish ./dist
```
