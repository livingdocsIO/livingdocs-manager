cheerio = require("cheerio")
helpers = require("../../utils/helpers")


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

    # check for one root element
    if $.root().children().length > 1
      err = new Error("The Design '#{design.config.name}', Template '#{templateName}' contains more than one root element")
      design.warn(err)

    html = helpers.minifyHtml($.html(), options, @name, design)
    design.debug("parsed template '#{templateName}'")
    new Template(templateName, html, config)


module.exports = Template
