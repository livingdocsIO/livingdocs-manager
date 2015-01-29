fs = require('fs')
mkdirp = require('mkdirp')
path = require('path')
EventEmitter = require('events').EventEmitter

helpers = require('../../utils/helpers')
Template = require('./template')


class Design extends EventEmitter

  constructor: (@options) ->
    @components = []
    @config = {}
    super


  initConfig: (@config={}, callback) ->
    @debug('initialize config file')

    for prop in ['name', 'version']
      unless @config[prop]
        return callback(new Error "Your configuration does not contain a '#{prop}'.")
    callback()


  initConfigFile: (filePath, callback) ->
    @debug('read config file')

    fs.readFile filePath, (err, file) =>
      if err
        if err.errno == 34 then err = new Error("The design in '#{path.dirname(filePath)}/' has no '#{path.basename(filePath)}' file.")
        return callback(err)

      try
        json = JSON.parse(file)
      catch err
        return callback(err)

      @initConfig(json, callback)


  addTemplate: (templateName, templateString) ->
    @debug("add template '#{templateName}'")

    template = Template.parse(templateName, templateString, @options, this)
    @components.push(template)


  addTemplateFile: (filePath, callback) ->
    templateName = helpers.filenameToTemplatename(filePath)
    @debug("read template '#{templateName}'")
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
    @debug('save design files')

    minify = if minify then 0 else 2
    javascript = @toJs(minify)
    javascript_dest = dest
    json = @toJson(minify)
    json_dest = dest.replace(/\.js/, '.json')

    @debug("save design.js file to #{javascript_dest}")
    mkdirp path.dirname(javascript_dest), (err) =>
      if err
        @emit('error', err)
        return @emit('end')

      fs.writeFile javascript_dest, javascript, (err) =>
        if err
          @emit('error', err)
          return @emit('end')

        @debug('saved design.js file')
        @debug('save design.json file')
        fs.writeFile json_dest, json, (err) =>
          @emit('error', err) if err
          @debug('saved design.json file') unless err
          @emit('end')


  debug: (string) ->
    @emit('debug', string)


  warn: (err) ->
    @emit('warn', err)


module.exports = Design
