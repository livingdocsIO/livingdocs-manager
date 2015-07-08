print = (string) ->
  console.log """--------------------------------------\n#{string}\n--------------------------------------\n"""


exports.token = (token) ->
  print """
    Access Token:
      #{token || ''}
  """


exports.user = (user) ->
  print """
    User:
      ID: #{user.id || ''}
      Created: #{user.created_at || ''}
      Updated: #{user.updated_at || ''}
      Admin: #{user.admin || false}
      Email: #{user.email || ''}
      First name: #{user.first_name || ''}
      Last name: #{user.last_name || ''}
      Space ID: #{user.space_id || ''}
  """
