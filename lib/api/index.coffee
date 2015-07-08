log = require('npmlog')
assert = require('assert')
_ = require('lodash')
request = require('request')
rc = require('rc')
mkdirp = require('mkdirp')


exports.authenticate = (options, callback) ->
  _.each ['user', 'password', 'host'], (prop) ->
    assert(typeof options[prop] is 'string', "The parameter 'options.#{prop}' is required")

  request
    method: 'post'
    url: options.host+'/authenticate'
    body:
      username: options.user
      password: options.password
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


exports.askAuthenticationOptions = (options, callback) ->
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


exports.space =
  get: (options, spaceId, callback) ->
    request
      method: 'get'
      url: "#{options.host}/spaces/#{spaceId}",
      headers: Authorization: "Bearer #{options.token}"
      json: true
    , (err, response, body) ->
      return callback(err) if err
      return callback(new Error("Invalid statusCode #{response.statusCode}")) if response.statusCode != 200
      callback(null, body.space)


  addDesign: (options, {space, design} = {}, callback) ->
    assertDesign(design)
    design =
      name: design.name
      version: design.version
      url: options.host+"/designs/#{design.name}/#{design.version}"
      is_selectable: true

    contained = _.find(space.config.designs, _.pick(design, 'name', 'version'))
    if contained
      log.info('space:addDesign', 'The space already contains such a design')
      return callback(null, space)

    space.config.designs ?= []
    space.config.designs.push(design)
    space.config.default_design = design
    updateConfig(options, space, callback)


  removeDesign: (options, {space, design} = {}, callback) ->
    assertDesign(design)
    space.config.designs ?= []
    contained = _.find(space.config.designs, design)
    isDefault = _.isEqual(_.pick(space.config.default_design, 'name', 'version'), _.pick(design, 'name', 'version'))
    if isDefault
      return callback(new Error("Can't remove a default design. Please add a new one first."))

    if !contained
      log.info('space:removeDesign', "The space doesn't contain such a design")
      return callback(null, space)

    space.config.designs = _.reject(space.config.designs, design)
    updateConfig(options, space, callback)


assertDesign = (design) ->
  assert(design.name, 'design.name is required')
  assert(design.version, 'design.version is required')


updateConfig = (options, space, callback) ->
  request
    method: 'put'
    url: "#{options.host}/spaces/#{space.id}/config",
    headers: Authorization: "Bearer #{options.token}"
    body: space.config
    json: true
  , (err, response, body) ->
    return callback(err) if err
    return callback(new Error("Invalid statusCode #{response.statusCode}")) if response.statusCode != 201
    callback(null, body.space)
