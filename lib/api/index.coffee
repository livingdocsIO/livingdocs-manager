path = require('path')
fs = require('fs')
assert = require('assert')
log = require('npmlog')
_ = require('lodash')
request = require('request')
rc = require('rc')
mkdirp = require('mkdirp')

module.exports = api =
  requestError: (res, body, message) ->
    if !message && res.statusCode == 400 && res.body?.error_details
      message = 'Server validation Error:\n'
      message += "#{key}: #{msg}\n" for key, msg of res.body.error_details
      err = new Error(message)
      err.stack = undefined

    else
      err = new Error(message || "Unhandled response code #{res.statusCode}")

    err.status = res.statusCode
    err.request =
      url: res.request.uri.href
      method: res.request.method
      headers: res.request.headers

    if body
      err.request.body = body

    err.response = res.toJSON()
    delete err.response.request

    err


  authenticate: (options, callback) ->
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
      if res?.statusCode == 401
        error = new Error('Authentication: Credentials invalid')
        callback(error)

      else if err
        error = new Error("Authentication: #{err.message}")
        error.stack = err.stack
        callback(error)

      else if res?.statusCode != 200
        error = new Error("Authentication: #{body.error}")
        body = username: options.username, password: '[redacted]'
        callback(api.requestError(res, body, "Authentication failed"))

      else
        callback null,
          user: body.user
          token: body.access_token


  askAuthenticationOptions: (args, callback) ->
    if args.host && args.user && args.password
      return callback(args)


    inquirer = require('inquirer')
    inquirer.prompt [
      name: 'host'
      message: 'Host'
      default: args.host
      validate: (val) ->
        return true if val.trim()
        'A design server is required to publish the design'
    ,
      name: 'user'
      message: 'Email'
      default: args.user
      validate: (val) -> /.*@.*/.test(val)
    ,
      name: 'password'
      message: 'Password'
      type: 'password'
      filter: (val) -> return val if !!val
      default: args.password
      validate: (val) ->
        return true if val.trim() && val.length > 5
        'The password must contain more than 5 characters.'
    ], (options) ->
      options = _.extend({}, args, options)
      options.host = "http://#{options.host}" unless /^(http|https):\/\//.test(options.host)
      if _.isEmpty(options.configs)
        configContent = JSON.stringify
          host: options.host
          user: options.user
        , null, 2

        configFilePath = path.join(options.dir, 'config')
        mkdirp path.dirname(configFilePath), (err) ->
          return callback(err) if err
          fs.writeFile configFilePath, configContent, (err) ->
            log.warn(err) if err
            callback(options)

      else
        callback(options)


api.project =
  get: (options, projectId, callback) ->
    request
      method: 'get'
      url: "#{options.host}/projects/#{projectId}",
      headers: Authorization: "Bearer #{options.token}"
      json: true
    , (err, res, body) ->
      return callback(err) if err
      return callback(api.requestError(res)) if res.statusCode != 200
      log.verbose('api:project:get', res.toJSON())
      callback(null, body.project)

  listDesigns: (options, projectId, callback) ->
    @get options, projectId, (err, project) ->
      return callback(err) if err
      callback null,
        defaultDesign: project.default_design
        designs: project.designs


  addDesign: (options, {projectId, design} = {}, callback) ->
    assertDesign(design)
    request
      method: 'post'
      url: "#{options.host}/projects/#{projectId}/add-design",
      headers: Authorization: "Bearer #{options.token}"
      body:
        name: design.name
        version: design.version
      json: true
    , (err, res, body) ->
      return callback(err) if err
      log.verbose('api:project:addDesign', 'Received error res')
      log.verbose('api:project:addDesign', res.toJSON())
      return callback(new Error("Invalid statusCode #{res.statusCode}")) if res.statusCode != 204
      callback(null)


  removeDesign: (options, {projectId, design} = {}, callback) ->
    assertDesign(design)
    request
      method: 'post'
      url: "#{options.host}/projects/#{projectId}/remove-design",
      headers: Authorization: "Bearer #{options.token}"
      body:
        name: design.name
        version: design.version
      json: true
    , (err, res, body) ->
      return callback(err) if err
      return callback(new Error("Invalid statusCode #{res.statusCode}")) if res.statusCode != 204
      callback(null)


assertDesign = (design) ->
  assert(design.name, 'design.name is required')
  assert(_.isString(design.version), 'design.version is required')
