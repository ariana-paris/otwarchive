json.creators do
  if work.anonymous?
    'Anonymous'
  else
    json.array!(work.pseuds.each) do |pseud|
      json.url        api_v1_user_url(pseud.user_id)
      json.name       pseud.name
      json.username   pseud.user_login
    end
  end
end