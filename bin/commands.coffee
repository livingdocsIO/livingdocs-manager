log = require('npmlog')
_ = require('lodash')
pkg = require('../package.json')
Design = require('../')
api = require('../lib/api')
minimist = require('minimist')
print = require('../lib/print')

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
      Usage: ldm <command>

      where: <command> is one of:

        help                       Show this information
        version                    Show the cli version

        user:info                  Prints the user information

        design:publish             Upload the design in the current directory
        design:build               Process the design in the current directory
        design:proxy               Start a design proxy server that caches designs

        project:design:list        List all designs of a project
        project:design:add         Add a design to a project
        project:design:remove      Remove a design from a project
      """

      # project:design:default     Set a design to a default
      # project:design:deprecate   Prevent document creation with a specific design version


  '-v': -> commands.version
  '--version': -> commands.version
  version:
    description: 'Show the script version'
    exec: (config) ->
      console.log(pkg.version)

  'design:publish':
    description: 'Show the script version'
    exec: (config) ->


  'user:info':
    description: 'Prints the user info'
    exec: (config) ->
      args = spaceDesignConfig()
      api.askAuthenticationOptions args, (options) ->
        api.authenticate options, (err, {user, token} = {}) ->
          return log.error(err) if err
          print.topic('User').user(user)()
          print.topic('Access token').line(token)()


  'publish': ->
    log.warn('`ldm publish` is obsolete. Please use `ldm design:publish`.')
    commands['design:publish']

  'design:publish':
    description: 'Show the script version'
    exec: (config) ->
      args = minimist process.argv.splice(3),
        string: ['user', 'password', 'host', 'source']
        alias:
          h: 'host'
          u: 'user'
          p: 'password'
          s: 'source'
          src: 'source'

      cwd = args.source || args._[0] || process.cwd()
      api.askAuthenticationOptions args, (options) ->
        options = _.extend({}, options, cwd: cwd)
        upload = require('../lib/upload')
        upload.exec options, (err, {design, url}={}) ->
          if err?.code == 'ENOENT'
            log.error('publish', 'No design.json file found in %s', cwd)

          else if err
            log.error('publish', err.stack)

          else
            log.info('publish', 'Published the design %s@%s to %s', design.name, design.version, url)


  'build': ->
    log.warn('`ldm publish` is obsolete. Please use `ldm design:build`.')
    commands['design:build']

  'design:build':
    description: 'Compile the design'
    exec: (config, callback) ->
      argv = process.argv.splice(3)
      args = minimist argv,
        string: ['source', 'destination']
        alias:
          s: 'source'
          src: 'source'
          d: 'destination'
          dst: 'destination'
          dest: 'destination'

      error = null
      args.source ?= args._[0] || process.cwd()
      args.destination ?= args._[1] || process.cwd()
      Design.build(src: args.source, dest: args.destination)
      .on 'debug', (debug) ->
        log.verbose('build', debug)

      .on 'warn', (warning) ->
        log.warn('build', warning)

      .on 'error', (err) ->
        error = err

      .on 'end', ->
        if error
          log.error('build', error)
        else
          log.info('build', 'Design compiled...')

        callback?(error)

  'design:proxy':
    description: 'Start a design server that caches designs'
    exec: (config, callback) ->
      args = minimist process.argv.splice(3),
        string: ['host', 'port']
        alias: h: 'host', p: 'port'

      args.host ?= 'http://api.livingdocs.io/designs'
      args.port ?= 3000

      proxy = require('../lib/design/proxy')
      proxy.start
        host: args.host
        port: args.port
      , (err, {server, port} = {}) ->
        if err?.code == 'EADDRINUSE'
          log.error('design:proxy', 'Failed to start the server on port %s', args.port)

        else if err
          log.error('design:proxy', err)

        else
          log.info('design:proxy', 'Server started on http://localhost:%s', port)


  'project:design:list':
    description: 'List all designs of a project'
    exec: (config, callback) ->
      authenticateSpace (err, {options, user, token} = {}) ->
        return log.error(err) if err
        api.space.listDesigns
          host: options.host
          token: token
        ,
          options.space
        , (err, {defaultDesign, designs} = {}) ->
          return log.error('design:list', err) if err
          print.topic('Default design').design(defaultDesign)()

          print.topic('Designs').each(designs, print.design)()


  'project:design:add':
    description: 'Add a design to a project'
    exec: (config, callback) ->
      authenticateSpace (err, {options, user, token} = {}) ->
        return log.error(err) if err
        api.space.addDesign
          host: options.host
          token: token
        ,
          spaceId: options.space
          design:
            name: options.name
            version: options.version
        , (err, space) ->
          return log.error('design:add', err) if err
          log.info('design:add', "The design '#{options.name}@#{options.version}' is now linked to your project.")


  'project:design:remove':
    description: 'Remove a design from a project'
    exec: (config, callback) ->
      authenticateSpace (err, {options, user, token} = {}) ->
        return log.error(err) if err
        api.space.removeDesign
          host: options.host
          token: token
        ,
          spaceId: options.space
          design:
            name: options.name
            version: options.version
        , (err, space) ->
          return log.error('design:remove', err) if err
          log.info('design:remove', "The design '#{options.name}@#{options.version}' got removed from your project.")


authenticateSpace = (callback) ->
  args = spaceDesignConfig()
  api.askAuthenticationOptions args, (options) ->
    api.authenticate options, (err, {user, token} = {}) ->
      return callback(err) if err
      options = _.extend({}, args, options)
      options.space ?= user.space_id
      callback(null, {options, user, token})


getSpace = (callback) ->
  args = spaceDesignConfig()
  api.askAuthenticationOptions args, (options) ->
    api.authenticate options, (err, {user, token} = {}) ->
      return log.error(err) if err

      spaceId = args.space || user.space_id
      log.info('design:add', "Adding the design to the space ##{spaceId}")

      api.space.get
        host: options.host
        token: token
      , spaceId, (err, space) ->
        return log.error(err) if err

        return log.error('design:add', 'A design name is required') unless args.name
        return log.error('design:add', 'A design version is required') unless args.version
        callback({args, options, space, user, token})


spaceDesignConfig = ->
  minimist process.argv.splice(3),
    string: ['user', 'password', 'host', 'space', 'name', 'version']
    alias:
      h: 'host'
      u: 'user'
      p: 'password'
      s: 'space'
      project: 'space'
      n: 'name'
      v: 'version'
