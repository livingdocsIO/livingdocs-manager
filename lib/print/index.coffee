_ = require('lodash')

print = (string, after) ->
  unless string
    console.log()
    return print

  string = string
  string += ": #{after}" if after
  console.log(string)
  print

print.line = print

print.topic = (string) ->
  console.log("=== #{string}")
  print


print.each = (arr, method) ->
  _.each(arr, (el) -> method.call(exports, el))
  print


print.channel = (channel) ->
  print
    .line "#{channel.name}"
    .line '  channel id', channel.id
    .line '  design name', channel.design_name
    .line '  current version', channel.current_version
    .line '  available versions', channel.available_versions.toString()
    .line '  disabled versions', channel.disabled_versions.toString()
    .line ''
  print


print.user = (user) ->
  print
    .line 'ID', user.id
    .line 'Created', user.created_at
    .line 'Updated', user.updated_at
    .line 'Admin', user.admin || false
    .line 'Email', user.email
    .line 'First name', user.first_name
    .line 'Last name', user.last_name
    .line 'Project ID', user.space_id

  print

module.exports = print
