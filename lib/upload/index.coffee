assert = require('assert')
request = require('request')


exports.askOptions = (options, done) ->
  return done(options) if options.host && options.user && options.password
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
    done(options)


authenticate = ({host, user, password}, callback) ->
  request
    method: 'post'
    url: host+'/authenticate'
    body: {username: user, password: password}
    json: true
  , (err, res, body) ->
    return callback("Authentication: " + err.message) if err
    return callback(new Error("Authentication: Credentials invalid")) if res.statusCode == 401
    return callback(new Error("Authentication: " + body.error)) if res.statusCode != 200
    callback(null, body)


# upload to the ☁️
exports.exec = ({design, user, password, host}={}, done) ->
  try
    assert(typeof design is 'object', "The parameter 'design' is required.")
    assert(typeof user is 'string', "The parameter 'user' is required")
    assert(typeof password is 'string', "The parameter 'password' is required")
    assert(typeof host is 'string', "The parameter 'host' is required")
  catch err
    return done(err)

  authenticate {host, user, password}, (err, res) ->
    if err
      return done(err)

    css = []
    for asset in design?.assets?.css || []
      css.push(url.resolve("http://livingdocs-designs.s3.amazonaws.com/timeline/0.0.1/", asset))
    design.assets.css = css if css.length

    request
      method: 'put'
      url: "http://api.livingdocs.io/designs/#{design.name}/#{design.version}"
      headers: Authorization: "Bearer #{res.access_token}"
      body: design
      json: true
    , (err, res, body) ->
      if err
        console.error(err)
        return done(err)

      console.log(body) if res.statusCode != 201
      done()
