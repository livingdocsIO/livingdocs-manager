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


print.design = (design) ->
  console.log("#{design?.name}@#{design?.version}")
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
    .line 'Space ID', user.space_id

  print

module.exports = print
