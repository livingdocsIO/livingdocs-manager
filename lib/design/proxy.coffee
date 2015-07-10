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
        stream = stream.pipe(designJSONTransform({name, version, basePath}))
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


designJSONTransform = ({name, version, basePath}) ->
  chunks = []
  stream = new require('stream').Readable()
  stream._read = ->
  stream.write = (data) -> chunks.push(data)
  stream.end = (err) ->
    buffer = Buffer.concat(chunks)
    try
     object = JSON.parse(buffer.toString())
     object.assets ?= {}
     object.assets.basePath = "#{basePath}/#{name}/#{version}"
     json = JSON.stringify(object)
    catch err
      return stream.emit('error', err)

    stream.push(json)
    stream.push(null)

  stream


getDesignStream = ({name, version, host, cachePath}, callback) ->
  filePath = path.join(cachePath, "#{name}-#{version}.tar.gz")
  if fs.existsSync(filePath)
    callback(null, fs.createReadStream(filePath))

  else
    tarUrl = "#{host}/#{name}/#{version}.tar.gz"
    request.get(tarUrl)
    .on 'error', (err) ->
      log.error('design:proxy', err)
      callback(err)

    .on 'response', (res) ->
      if res.statusCode != 200
        log.info('design:proxy', "Failed to fetch '#{tarUrl}'. Received statusCode #{res.statusCode}")
        callback()

      else
        tmpFile = filePath+'.tmp'
        write = fs.createWriteStream(tmpFile)
        write.on 'finish', -> fs.rename(tmpFile, filePath)
        write.on 'error', -> fs.unlink(tmpFile)
        res.pipe(write)
        callback(null, res)


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


