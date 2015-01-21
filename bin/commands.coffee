path = require('path')
log = require('npmlog')
_ = require('lodash')
pkg = require('../package.json')
Design = require('../')

exports.init = (config, callback) ->
  callback()


exports.trigger = (command='help', config) ->
  action = commands[command]
  action = action() if _.isFunction(action)
  if action
    action.exec?(config)

  else
    log.error('cli', "The command '#{command}' isn't available")
    console.log('')
    commands.help.exec(config)


commands =

  '-h': -> commands.help
  '--help': -> commands.help
  help:
    description: 'Show all commands'
    exec: ->
      console.log """
      Usage: livingdocs <command>

      where: <command> is one of:

        help:       show this information
        version:    show the cli version
        publish:    upload the design in the current directory
        build:      process the design in the current directory
      """


  version:
    description: 'Show the script version'
    exec: (config) ->
      console.log(pkg.version)


  publish:
    description: 'Show the script version'
    exec: (config) ->
      minimist = require('minimist')
      args = minimist process.argv.splice(3),
        string: ['user', 'password', 'host']
        alias:
          h: 'host'
          u: 'user'
          p: 'password'

      upload = require('../lib/upload')
      upload.askOptions args, (options) ->

        cwd = process.cwd()
        design = JSON.parse(require('fs').readFileSync(path.join(cwd, 'design.json')))
        options = _.extend({}, options, design: design)
        upload.exec options, (err) ->
          return log.error(err) if err
          log.info('upload', 'Uploaded the design %s@%s', options.design.name, options.design.version)


  build:
    description: 'Compile the design'
    exec: (config, callback) ->
      path = require('path')
      error = null
      cwd = process.cwd()
      Design.build(src: cwd, dest: cwd)
      .on 'debug', (debug) ->
        log.verbose('build', debug)

      .on 'warn', (warning) ->
        log.warn('build', warning.stack)

      .on 'error', (err) ->
        error = err

      .on 'end', ->
        if error
          log.error('build', error)
        else
          log.info('build', 'Design compiled...')

        callback?(error)
