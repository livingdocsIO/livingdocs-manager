log = require('npmlog')
path = require('path')
_ = require('lodash')
pkg = require('../package.json')
Design = require('../')
api = require('../lib/api')
minimist = require('minimist')
print = require('../lib/print')
config = require('./config')


execChannelAction = ({identifier, method, message}) ->
  ->
    authenticateProject (err, {options, token} = {}) ->
      return log.error("channel:design-version:#{identifier}", err) if err
      api.project[method]
        host: options.host
        token: token
      ,
        channelId: options.channel
        designVersion: options['version']
      , (err) ->
        return log.error("channel:design-version:#{identifier}", err) if err
        log.info("channel:design-version:#{identifier}", message.replace('{{design}}', "#{options.version}"))


exports.init = (callback) ->
  callback()


exports.trigger = (command='help') ->
  action = commands[command]
  action = action() if _.isFunction(action)
  if action
    action.exec?()

  else
    log.error('cli', "The command '#{command}' isn't available")
    console.log('')
    commands.help.exec()


commands =

  '-h': -> commands.help
  '--help': -> commands.help
  help:
    description: 'Show this information'
    exec: ->
      print
        .line('Usage', 'ldm <command>')()
        .line('where','<command> is one of:')

      previousTopic = undefined
      _.each commands, (command, key) ->
        return unless command?.description
        topic = key.split(':')?[0]
        print.line() if topic != previousTopic
        print.line("  #{_.padRight(key, 35)}#  #{command.description}")
        previousTopic = topic


  '-v': -> commands.version
  '--version': -> commands.version
  version:
    description: 'Show the cli version'
    exec: ->
      console.log(pkg.version)


  'user:info':
    description: 'Prints the user information'
    exec: ->
      authenticate (err, {host, user, token} = {}) ->
        return log.error('user:info', err) if err
        print.topic('User').user(user)()
        print.topic('Access token').line(token)()


  'build': ->
    log.warn('`ldm build` is obsolete. Please use `ldm design:build`.')
    commands['design:build']


  'design:build':
    description: 'Compile the design'
    exec: ->
      argv = process.argv.slice(3)
      args = minimist argv,
        string: ['source', 'destination']
        alias:
          s: 'source'
          src: 'source'
          d: 'destination'
          dst: 'destination'
          dest: 'destination'

      args.source = args._[0] || process.cwd()
      args.destination = args._[1] || process.cwd()

      error = null
      Design.build(src: args.source, dest: args.destination)
      .on 'debug', (debug) ->
        log.verbose('build', debug)

      .on 'warn', (warning) ->
        log.warn('build', warning)

      .on 'error', (err) ->
        error = err

      .on 'end', ->
        if error
          log.error('design:build', error)
        else
          log.info('design:build', 'Design compiled...')

        callback?(error)


  'publish': ->
    log.warn('`ldm publish` is obsolete. Please use `ldm design:publish`.')
    commands['design:publish']


  'design:publish':
    description: 'Show the script version'
    exec: ->
      args = minimist process.argv.slice(3),
        string: ['source']
        alias: s: 'source', src: 'source'

      args.source = path.resolve(args.source || args._[0] || './')
      authenticate (err, {token, host} = {}) ->
        return log.error('design:publish', 'Failed to authenticate', err) if err
        upload = require('../lib/upload')
        upload.exec
          host: host
          token: token
          cwd: args.source
        , (err, {design, url} = {}) ->
          if err?.code == 'ENOENT'
            log.error('design:publish', 'No design.json file found in %s', args.source)

          else if err
            log.error('design:publish', err)

          else
            log.info('design:publish', 'Published the design %s@%s to %s', design.name, design.version, url)


  'design:proxy':
    description: 'Start a design server that caches designs'
    exec: ->
      args = minimist process.argv.slice(3),
        string: ['host', 'port']
        alias: h: 'host', p: 'port'

      args.host ?= 'http://api.livingdocs.io'
      args.port ?= 3000

      proxy = require('../lib/design/proxy')
      proxy.start
        host: args.host
        port: args.port
        cacheDirectory: path.join(config.cache, 'design-proxy')
      , (err, {server, port} = {}) ->
        if err?.code == 'EADDRINUSE'
          log.error('design:proxy', 'Failed to start the server on port %s', args.port)

        else if err
          log.error('design:proxy', err)

        else
          log.info('design:proxy', 'Server started on http://localhost:%s', port)


  ## feature requests:
  # project:design:default     Set a design to a default
  # project:design:deprecate   Prevent document creation with a specific design version

  'project:channel:list':
    description: 'List all channels of a project'
    exec: ->
      authenticateProject (err, {options, token} = {}) ->
        return log.error('project:design:list', err) if err
        api.project.listDesigns
          host: options.host
          token: token
        ,
          options.project
        , (err, {channels, defaultChannel} = {}) ->
          return log.error('project:design:list', err) if err
          print
            .topic('Default Channel Name')
            .line(defaultChannel?.name)()
          print
            .topic('Channels')
            .each(channels, print.channel)()


  'channel:design-version:add':
    description: 'Add a design-version to a channel'
    exec: execChannelAction
      method: 'addDesignVersion'
      identifier: 'add'
      message: 'The designVersion {{design}} is now linked to your channel.'


  'channel:design-version:remove':
    description: 'Remove a design-version from a channel'
    exec: execChannelAction
      method: 'removeDesignVersion'
      identifier: 'remove'
      message: 'The designVersion {{design}} got removed from your channel.'


  'channel:design-version:current':
    description: 'Set the current design-version for a channel'
    exec: execChannelAction
      method: 'setCurrentDesignVersion'
      identifier: 'current'
      message: 'The new current designVersion is {{design}}.'


  'channel:design-version:enable':
    description: "Enable a design-version of a channel"
    exec: execChannelAction
      method: 'enableDesignVersion'
      identifier: 'enable'
      message: 'The designVersion {{design}} is now enabled for your channel.'


  'channel:design-version:disable':
    description: "Disable a design-version of a channel"
    exec: execChannelAction
      method: 'disableDesignVersion'
      identifier: 'disable'
      message: 'The designVersion {{design}} is now disabled for your channel.'


authenticate = (callback) ->
  defaults = minimist process.argv.slice(3),
    string: ['user', 'password', 'host']
    default:
      host: config.host
      user: config.user
      dir: config.dir # configdir
      configs: config.configs # existing configfiles
    alias:
      h: 'host'
      u: 'user'
      p: 'password'

  api.askAuthenticationOptions defaults, (options) ->
    api.authenticate
      host: options.host
      user: options.user
      password: options.password
    , (err, {user, token} = {}) ->
      return callback(err) if err
      callback(null, {user, token, host: options.host})


authenticateProject = (callback) ->
  c = minimist process.argv.slice(3),
    string: ['project', 'name', 'version']
    alias:
      s: 'project'
      project: 'project'
      n: 'name'

  if Array.isArray(c.project)
    c.project = c.project.pop()

  authenticate (err, {user, token, host} = {}) ->
    return callback(err) if err
    callback null,
      token: token
      options:
        host: host
        project: c.project || user.project_id || user.space_id
        channel: c.channel
        name: c.name
        version: c.version
