fs = require('fs')
util = require('util')
path = require('path')
assert = require('assert')
request = require('request')
url = require('url')
async = require('async')
log = require('npmlog')
utils = require('../utils')
_ = require('lodash')
Glob = require('glob')
api = require('../api')

validateDesign = (design) ->
  assert(typeof design is 'object', 'The design must be an object literal.')
  assert(typeof design.name is 'string', "The design requires a property 'design.name'.")
  assert(typeof design.version is 'string', "The design requires a property 'design.version'.")


# upload to the ☁️
exports.exec = (options, callback) ->
  {cwd, token, host} = options || {}

  try
    assert(typeof cwd is 'string', "The parameter 'options.cwd' is required")

    design = JSON.parse(fs.readFileSync(path.join(cwd, 'design.json')))
    validateDesign(design)

  catch err
    return callback(err)

  exports.putJson {design, token, host}, (err, {design, url}={}) ->
    return callback(err) if err

    exports.uploadAssets {cwd, host, token, design}, (err) ->
      return callback(err) if err
      callback(null, {design, url})


exports.putJson = ({design, host, token}, callback) ->
  log.verbose('design:publish', "Uploading the design %s@%s to %s", design.name, design.version, host)
  designUrl = host+"/designs/#{design.name}/#{design.version}"
  request
    method: 'put'
    url: designUrl
    headers: Authorization: "Bearer #{token}"
    body: design
    json: true
  , (err, res, body) ->
    return callback(err) if err
    if res.statusCode == 200
      body = {design: design, url: designUrl}
      return callback(null, body)

    callback(api.requestError(res, design))


exports.uploadAssets = ({cwd, design, host, token}, callback) ->
  new Glob '**/*', cwd: cwd, (err, files) ->
    return callback(err) if err

    files = files.filter (file) -> return !/^design.js(on)?$/.test(file)
    async.eachLimit files, 10, (file, done) ->
      file = path.join(cwd, file)
      fs.stat file, (err, stats) ->
        return done(err) if err || !stats.isFile()
        exports.uploadAsset({cwd, design, host, token, file}, done)
    , callback


exports.uploadAsset = ({cwd, design, host, token, file}, callback) ->
  relativePath = utils.pathToRelativeUrl(cwd, file)
  request
    method: 'post'
    url: host+"/designs/#{design.name}/#{design.version}/assets"
    headers:
      Authorization: "Bearer #{token}"
    formData:
      path: relativePath
      file: fs.createReadStream(file)
  , (err, res, body) ->
    return callback(err) if err
    if res.statusCode in [200, 201]
      log.info('asset', "Succeeded to upload the file '#{relativePath}'")
    else
      log.error('asset', api.requestError(res))
    callback()
