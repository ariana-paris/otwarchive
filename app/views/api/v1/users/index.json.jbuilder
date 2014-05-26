# Include count of listed objects
json.total_count @users.to_a.count

# Include the same partial to render each user
# as for showing individual users (probably should be changed)
json.users @users do |user|
  json.partial! 'show', user: user, num: 5
end