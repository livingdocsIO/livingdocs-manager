_ = require('lodash')
cheerio = require("cheerio")
utils = require("../../utils")


class Template
  constructor: (@name, @html, config) ->
    for key, val of config
      this[key] = val

    @name = config.name || @name
    @label ?= @name


  @parse: (templateName, templateString, options, design) ->
    design.debug("Parse the template '#{templateName}' of the design '#{design.config.name}'.")

    $ = cheerio.load(templateString)
    config = JSON.parse($(options.configurationElement).html()) || {}
    $(options.configurationElement).remove()

    # filter out comment & text nodes
    # check for one root element
    children = _.filter($.root().contents(), (el) -> el.nodeType == 1)
    if children.length != 1
      err = new Error("The design '#{design.config.name}', template '#{templateName}' contains #{children.length} root elements. Components only work with one root element.")
      design.warn(err)

    outerHtml = $.html(children[0])
    try
      html = utils.minifyHtml(outerHtml, options, templateName)
    catch err
      design.warn("Failed to minify the tempate '#{templateName}' of the design '#{design.config.name}'.")
      design.warn("#{err}")
      html = ''

    design.debug("Parsed the template '#{templateName}' of the design '#{design.config.name}'.")
    new Template(templateName, html, config)


module.exports = Template
