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
