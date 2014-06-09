json.creators do
  if work.anonymous?
    'Anonymous'
  else
    json.array!(work.pseuds.each) do |pseud|
      json.id             pseud.id
      json.url            api_v1_user_url(pseud.user_id)
      json.display_name   pseud.name
      json.user_id        pseud.user_id
      json.username       pseud.user_login
    end
  end
end