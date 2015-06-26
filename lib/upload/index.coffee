fs = require('fs')
mkdirp = require('mkdirp')
util = require('util')
path = require('path')
assert = require('assert')
request = require('request')
url = require('url')
async = require('async')
log = require('npmlog')
utils = require('../utils')
rc = require('rc')
_ = require('lodash')
Glob = require('glob')


exports.askOptions = (options, callback) ->
  if options.host && options.user && options.password
    return callback(options)

  conf = rc 'livingdocs',
    host: 'http://api.livingdocs.io'
    user: "#{process.env.USER}@upfront.io"

  inquirer = require('inquirer')
  inquirer.prompt [
    name: 'host'
    message: 'Host'
    default: conf.host
    validate: (val) ->
      return true if val.trim()
      'A design server is required to publish the design'
  ,
    name: 'user'
    message: 'Email'
    default: conf.user
    validate: (val) -> /.*@.*/.test(val)
  ,
    name: 'password'
    message: 'Password'
    type: 'password'
    filter: (val) -> return val if !!val
    default: options.password
    validate: (val) ->
      return true if val.trim() && val.length > 5
      'The password must contain more than 5 characters.'
  ], (options) ->
    options.host = "http://#{options.host}" unless /^(http|https):\/\//.test(options.host)

    home = require('os-homedir')()
    if _.isEmpty(conf.configs) && home
      configContent = JSON.stringify
        host: options.host
        user: options.user
      , null, 2

      configPath = path.join(home, '.livingdocs')
      configFilePath = path.join(configPath, 'config')
      mkdirp configPath, (err) ->
        return callback(err) if err
        fs.writeFile configFilePath, configContent, (err) ->
          log.warn(err) if err
          callback(options)

    else
      callback(options)


exports.authenticate = ({host, user, password}, callback) ->
  request
    method: 'post'
    url: host+'/authenticate'
    body:
      username: user
      password: password
    json: true
  , (err, res, body) ->
    if err
      error = new Error("Authentication: #{err.message}")
      error.stack = err.stack

    if res.statusCode == 401
      error = new Error('Authentication: Credentials invalid')

    if res.statusCode != 200
      error = new Error("Authentication: #{body.error}")

    return callback(error) if error
    callback null,
      user: body.user
      token: body.access_token


validateDesign = (design) ->
  assert(typeof design is 'object', 'The design must be an object literal.')
  assert(typeof design.name is 'string', "The design requires a property 'design.name'.")
  assert(typeof design.version is 'string', "The design requires a property 'design.version'.")


# upload to the ☁️
exports.exec = (options={}, callback) ->
  {cwd, user, password, host} = options

  try
    _.each ['cwd', 'user', 'password', 'host'], (prop) ->
      assert(typeof options[prop] is 'string', "The parameter 'options.#{prop}' is required")

    design = JSON.parse(fs.readFileSync(path.join(cwd, 'design.json')))
    validateDesign(design)

  catch err
    return callback(err)

  exports.authenticate options, (err, {user, token}={}) ->
    return callback(err) if err
    exports.putJson {design, token, host}, (err, {design, url}={}) ->
      return callback(err) if err
      exports.uploadAssets {cwd, design, host, token}, (err) ->
        return callback(err) if err
        callback(null, {design, url})


exports.putJson = ({design, host, token}, callback) ->
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

    error = new Error(body.error || "Unhandled response code #{res.statusCode}")
    error.error_details = body.error_details
    callback(error)


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
      log.error('asset', body)
    callback()
