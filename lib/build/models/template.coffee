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
    design.debug("parse template '#{templateName}'")

    $ = cheerio.load(templateString)
    config = JSON.parse($(options.configurationElement).html()) || {}
    $(options.configurationElement).remove()

    # filter out comment nodes,
    # check for one root element
    children = _.filter($.root().children(), (el) -> el.nodeType != 8)
    if children.length != 1
      err = new Error("The Design '#{design.config.name}', Template '#{templateName}' contains #{children.length} root elements. Only 1 is supported.")
      design.warn(err)

    html = utils.minifyHtml($.html(), options, @name, design)
    design.debug("parsed template '#{templateName}'")
    new Template(templateName, html, config)


module.exports = Template
