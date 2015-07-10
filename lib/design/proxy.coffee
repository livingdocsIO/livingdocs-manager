assert = require('assert')
path = require('path')
fs = require('fs')
_ = require('lodash')
express = require('express')
request = require('request')
mime = require('mime')
tar = require('tar-stream')
gunzip = require('gunzip-maybe')
log = require('npmlog')
eos = require('end-of-stream')


exports.start = (config, callback) ->
  assert(config.host, 'proxy.start(config, callback) requires a config.host param.')
  assert(config.port, 'proxy.start(config, callback) requires a config.port param.')
  basePath = undefined

  cachePath = path.join(process.cwd(),'ldm-design-proxy-cache')
  fs.mkdir cachePath, (err) ->
    return callback(err) if err && err.code != 'EEXIST'

    app = express()
    app.use (req, res, next) ->
      res.header('Access-Control-Allow-Origin', '*')
      res.header('Access-Control-Allow-Methods', "OPTIONS, GET, PUT, POST, PATCH, DELETE")

      if req.method == 'OPTIONS'
        res.header('Access-Control-Allow-Headers', "Cache-Control, Pragma, Origin, Authorization, Content-Type, X-Requested-With")
        return res.sendStatus(204)

      next()

    app.get '/designs/:name/:version', (req, res) ->
      name = req.params.name
      version = req.params.version
      getDesignFileStream
        host: config.host
        name: name
        version: version
        file: 'design.json'
        cachePath: cachePath
      , (err, {stream, contentType} = {}) ->
        return sendFile(res)(err) if err || !stream
        stream = stream.pipe(new DesignTransform({name, version, basePath}))
        sendFile(res)(null, {stream, contentType})

    app.get '/designs/:name/:version/:file(*)', (req, res) ->
      getDesignFileStream
        host: config.host
        name: req.params.name
        version: req.params.version
        file: req.params.file
        cachePath: cachePath
      , sendFile(res)

    server = app.listen config.port, (err) ->
      if err
        callback(err, server: server)

      else
        port = server.address().port
        basePath = "http://localhost:#{port}/designs"
        callback(null, server: server, port: port)


sendFile = (res) ->
  (err, {stream, contentType} = {}) ->
    return res.status(500).send(err) if err
    return res.sendStatus(404) if !stream
    res.set('content-type', contentType)
    stream.pipe(res)


getDesignStream = (options, callback) ->
  filePath = path.join(options.cachePath, "#{options.name}-#{options.version}.tar.gz")
  tmpFilePath = filePath+'.tmp'

  fs.exists filePath, (exists) ->
    return callback(null, fs.createReadStream(filePath)) if exists
    tarUrl = "#{options.host}/#{options.name}/#{options.version}.tar.gz"
    request.get(tarUrl)
    .on 'error', (err) ->
      log.error('design:proxy', err)
      callback(err)

    .on 'response', (res) ->
      if res.statusCode != 200
        log.info('design:proxy', "Failed to fetch '#{tarUrl}'. Received statusCode #{res.statusCode}")
        callback()

      else
        write = fs.createWriteStream(tmpFilePath)
        callbacked = false
        cleanup = (err) ->
          return if callbacked
          callbacked = true
          fs.unlink tmpFilePath, -> log.error('design:proxy', err)
          callback(err)

        eos write, (err) ->
          return cleanup(err) if err
          fs.rename tmpFilePath, filePath, (err) ->
            return cleanup(err) if err
            log.info('design:proxy', "Successfully cached '#{tarUrl}'")
            getDesignStream(options, callback)

        eos res, (err) ->
          return cleanup(err) if err

        res.pipe(write)


getDesignFileStream = ({name, version, host, file, cachePath}, callback) ->
  callback = _.once(callback)
  extract = tar.extract()
  extract.on 'entry', (header, stream, done) ->
    if header.name != "undefined/#{file}"
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
  getDesignStream {name, version, host, cachePath}, (err, stream) ->
    return callback(err) if err || !stream
    stream.pipe(gunzip()).pipe(extract)



class DesignTransform extends require('stream').Readable

  constructor: ({name, version, basePath}) ->
    super()
    @_rawDesign = []


  _read: ->


  write: (chunk) ->
    @_rawDesign.push(chunk)


  end: (err) ->
    buffer = Buffer.concat(@_rawDesign)
    try
     object = JSON.parse(buffer.toString())
     object.assets ?= {}
     object.assets.basePath = "#{@basePath}/#{@name}/#{@version}"
     json = JSON.stringify(object)
    catch err
      return @emit('error', err)

    @push(json)
    @push(null)
