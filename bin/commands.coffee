path = require('path')
log = require('npmlog')
assert = require('assert')
_ = require('lodash')
pkg = require('../package.json')
Design = require('../')
api = require('../lib/api')
minimist = require('minimist')

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

        design:publish             Upload the design in the current directory
        design:build               Process the design in the current directory
        design:proxy               Start a proxy server

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
          return log.error('publish', 'No design.json file found in %s', cwd) if err.code == 'ENOENT'
          return log.error('publish', err.stack) if err
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
        alias:
          h: 'host'
          p: 'port'

      fs = require('fs')
      express = require('express')
      request = require('request')
      mime = require('mime')
      tar = require('tar-stream')
      gunzip = require('gunzip-maybe')

      host = args.host || 'http://api.livingdocs.io/designs'
      port = args.port || 3000

      cachePath = path.join(process.cwd(),'ld-design-cache')
      try
        fs.mkdirSync(cachePath)
      catch err
        throw err unless err.code == 'EEXIST'

      getDesignStream = ({name, version}, callback) ->
        filePath = path.join(cachePath, "#{name}-#{version}.tar.gz")
        if fs.existsSync(filePath)
          callback(null, fs.createReadStream(filePath))
        else
          tarUrl = "#{host}/#{name}/#{version}.tar.gz"
          stream = request(tarUrl)
          write = fs.createWriteStream(filePath)
          stream.pipe(write)
          callback(null, stream)

      getDesignFileStream = ({name, version, file}, callback) ->
        extract = tar.extract()
        extract.on 'entry', (header, stream, done) ->
          if !_.endsWith(header.name, file)
            stream.resume()
            done()

          else
            contentType = mime.lookup(header.name)
            callback(null, {contentType, stream})

            destroy = ->
              stream.destroy()
              extract.destroy()

            stream.on 'error', destroy
            stream.on 'end', destroy

        extract.on 'finish', -> callback()
        getDesignStream {name, version}, (err, stream) ->
          return callback(err) if err || !stream
          stream.pipe(gunzip()).pipe(extract)

      sendFile = (res) ->
        (err, {stream, contentType} = {}) ->
          return res.status(500).send(err) if err
          return res.sendStatus(404) if !stream
          res.set('content-type', contentType)
          stream.pipe(res)

      app = express()
      app.get '/designs/:name/:version', (req, res) ->
        getDesignFileStream
          name: req.params.name
          version: req.params.version
          file: 'design.json'
        , sendFile(res)

      app.get '/designs/:name/:version/:file(*)', (req, res) ->
        getDesignFileStream req.params, sendFile(res)


      server = app.listen port, (err) ->
        if err
          log.error('proxy', 'Failed to start server on port %s', port)

        else
          log.info('proxy', 'Server started on http://localhost:%s', server.address().port)


  'project:design:add':
    description: 'Add a design to a project'
    exec: (config, callback) ->
      getSpace ({args, options, space, user, token}) ->
        api.space.addDesign
          host: options.host
          token: token
        ,
          space: space
          design:
            name: args.name
            version: args.version
        , (err, space) ->
          return log.error(err) if err
          log.info('design:add', "The design '#{args.name}@#{args.version}' is now linked to your project.")


  'project:design:remove':
    description: 'Remove a design from a project'
    exec: (config, callback) ->
      getSpace ({args, options, space, user, token}) ->
        api.space.removeDesign
          host: options.host
          token: token
        ,
          space: space
          design:
            name: args.name
            version: args.version
        , (err, space) ->
          return log.error(err) if err
          log.info('design:remove', "The design '#{args.name}@#{args.version}' got removed from your project.")


getSpace = (callback) ->
  args = spaceDesignConfig()
  api.askAuthenticationOptions args, (options) ->
    api.authenticate options, (err, {user, token}={}) ->
      return log.error(err) if err

      spaceId = args.space || user.space_id
      log.info('design:add', "Adding the design to the space ##{spaceId}")

      api.space.get
        host: options.host
        token: token
      , spaceId, (err, space) ->
        return log.error(err) if err

        return log.error('design.add', 'A design name is required') unless args.name
        return log.error('design.add', 'A design version is required') unless args.version
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
