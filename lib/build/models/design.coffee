fs = require('fs')
mkdirp = require('mkdirp')
path = require('path')
EventEmitter = require('events').EventEmitter

utils = require('../../utils')
Template = require('./template')


class Design extends EventEmitter

  constructor: (@options) ->
    @components = []
    @config = {}
    super


  initConfig: (@config={}, callback) ->
    @debug('Initialize config object')

    for prop in ['name', 'version']
      if !@config[prop]
        return invalidConfigError(prop, callback)

    callback()


  initConfigFile: (filePath, callback) ->
    @debug('Read config file')

    fs.readFile filePath, (err, file) =>
      if err
        return configReadError(filePath, err, callback)

      try
        json = JSON.parse(file)
      catch err
        return callback(err)

      @initConfig json, (err) ->
        if err && err.code == 'InvalidConfig'
          err.message += "Please edit your configuration in #{filePath}."

        callback(err)


  addTemplate: (templateName, templateString) ->
    @debug("Add template '#{templateName}'")

    template = Template.parse(templateName, templateString, @options, this)
    @components.push(template)


  addTemplateFile: (filePath, callback) ->
    templateName = utils.filenameToTemplatename(filePath)
    @debug("Read template '#{templateName}'")
    fs.readFile filePath, (err, templateString) =>
      return callback(err) if err
      @addTemplate(templateName, templateString)
      callback()


  toJson: (minify) ->
    data = @config
    data.components = @components
    JSON.stringify(data, null, minify||0)


  toJs: (minify) ->
    templateBegin = "(function () { var designJSON = "
    templateEnd = "; if(typeof module !== 'undefined' && module.exports) {return module.exports = designJSON;} else { this.design = this.design || {}; this.design.#{@config.name} = designJSON;} }).call(this);"
    fileData = templateBegin + @toJson(minify) + templateEnd


  # write the config and templates to disk
  save: (dest, minify) ->
    @debug('Save design files')

    minify = if minify then 0 else 2
    javascript = @toJs(minify)
    javascript_dest = dest
    json = @toJson(minify)
    json_dest = dest.replace(/\.js/, '.json')

    @debug("Save design.js file to #{javascript_dest}")
    mkdirp path.dirname(javascript_dest), (err) =>
      return @error(err) if err

      fs.writeFile javascript_dest, javascript, (err) =>
        return @error(err) if err

        @debug('Saved design.js file')
        @debug('Save design.json file')
        fs.writeFile json_dest, json, (err) =>
          return @error(err) if err

          @debug('Saved design.json file') unless err
          @emit('end')


  debug: (string) ->
    @emit('debug', string)


  warn: (err) ->
    @emit('warn', err)


  error: (err) ->
    @emit('error', err)
    @emit('end')


module.exports = Design


configReadError = (filePath, err, callback) ->
  if err.errno == 34
    err = new Error("The design in '#{path.dirname(filePath)}/' has no '#{path.basename(filePath)}' file.")
    err.code == 'MissingConfig'

  callback(err)


invalidConfigError = (prop, callback) ->
  err = new Error("Your configuration does not contain a '#{prop}'.")
  err.code = 'InvalidConfig'
  return callback(err)
