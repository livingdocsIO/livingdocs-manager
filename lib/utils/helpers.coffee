path = require('path')
htmlmin = require('html-minifier')

exports.filenameToTemplatename = (string) ->
  strings = string.replace(/\.[a-z]{2,4}$/, '').split('/')
  strings[strings.length - 1]


exports.minifyHtml = (html, options, templateName, ee) ->
  if options?.minify
    try
      htmlmin.minify(html, options.minify)
    catch err
      warning = ">> Template \"#{templateName}\": HTML minify error\n #{err}\n"
      if ee
        ee.emit('warn', warning)
      else
        console.warn(warning)

      return '<div class="error minify" style="color: red">Error while minifying: Template "#{templateName}"</div>'

  else
    html.trim()
