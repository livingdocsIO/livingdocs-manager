fs = require('fs')
path = require('path')
assert = require('assert')
request = require('request')
url = require('url')
async = require('async')
log = require('npmlog')


exports.askOptions = (options, callback) ->
  return callback(options) if options.host && options.user && options.password
  inquirer = require('inquirer')
  inquirer.prompt [
    name: 'host'
    message: 'Host'
    default: options.host || "http://api.livingdocs.io"
  ,
    name: 'user'
    message: 'Email'
    default: options.user || "#{process.env.USER}@upfront.io"
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
    callback(options)


exports.authenticate = ({host, user, password}, callback) ->
  request
    method: 'post'
    url: host+'/authenticate'
    body: {username: user, password: password}
    json: true
  , (err, res, body) ->
    return callback("Authentication: " + err.message) if err
    return callback(new Error("Authentication: Credentials invalid")) if res.statusCode == 401
    return callback(new Error("Authentication: " + body.error)) if res.statusCode != 200
    callback(null, user: body.user, accessToken: body.access_token)


# upload to the ☁️
exports.exec = ({cwd, user, password, host}={}, callback) ->
  try
    design = JSON.parse(fs.readFileSync(path.join(cwd, 'design.json')))
    assert(typeof design is 'object', "The parameter 'design' is required.")
    assert(typeof design.name is 'string', "The design requires a property 'name'.")
    assert(typeof design.version is 'string', "The design requires a property 'version'.")

    assert(typeof user is 'string', "The parameter 'user' is required")
    assert(typeof password is 'string', "The parameter 'password' is required")
    assert(typeof host is 'string', "The parameter 'host' is required")
  catch err
    return callback(err)

  exports.authenticate {host, user, password}, (err, {user, accessToken:token}={}) ->
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
    if res?.statusCode == 200
      body = {design: design, url: designUrl}
      return callback(null, body)

    error = new Error(body.error || "Unhandled response code #{statusCode}")
    error.error_details = body.error_details
    callback(error)


exports.uploadAssets = ({cwd, design, host, token}, callback) ->
  Glob = require('glob')
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
  relativePath = file.replace(cwd, '')
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
    if res.statusCode == 200
      log.info('asset', "Uploaded the file '#{relativePath}'")
    else
      log.error('asset', body)
    callback()
