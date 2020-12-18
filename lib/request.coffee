request = require('request').defaults({jar: true})
_ = require('lodash')
parseWarningHeader = require('warning-header-parser')
log = require('npmlog')

module.exports = (config, callback) ->
  request config, (err, res) ->
    callback.apply(null, arguments)
    if res?.headers.warning
      logWarningHeaders(res.headers.warning, res.request)

  undefined


logWarningHeaders = (string, req) ->
  warnings = parseWarningHeader(string).map (w) -> w.message
  log.warn('request', ["Warnings on #{req.method} #{req.href}:"].concat(warnings).join('\n  '))
