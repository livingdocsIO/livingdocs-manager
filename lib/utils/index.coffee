path = require('path')
htmlmin = require('html-minifier')

exports.filenameToTemplatename = (string) ->
  strings = string.replace(/\.[a-z]{2,4}$/, '').split('/')
  strings[strings.length - 1]


exports.minifyHtml = (html, options) ->
  if options?.minify
    htmlmin.minify(html, options.minify)

  else
    html.trim()


exports.pathToRelativeUrl = (cwd, filepath) ->
  filepath.replace(cwd, '').split(path.delimiter).join('/')
