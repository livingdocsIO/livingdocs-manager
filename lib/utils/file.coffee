fs = require('fs')
path = require('path')
mkdirp = require('mkdirp')

exports.write = (file, data, callback) ->
  mkdirp path.dirname(file), (err) ->
    return callback(err) if err
    fs.writeFile(file, data, callback)


exports.readFile = fs.readFile
exports.readJson = (file, callback) ->
  fs.readFile file, encoding:'utf8', (err, content) ->
    return callback(err) if err
    try
      content = JSON.parse(content)
    catch err
      return callback(err) if err

    callback(null, content)
