# Partial for rendering one user
json.extract! user, :id, :login

json.pseudonyms(user.pseuds) do |pseud|
  json.id             pseud.id
  json.display_name   pseud.name
end

# List a few works
works = user.works.visible_to_all.revealed.non_anon.to_a
if num.nil?
  json.works works do |work|
    json.title work.title
    json.url   api_v1_work_url(work)
  end
else
  json.works works.first(num) do |work|
    json.title work.title
    json.url   api_v1_work_url(work)
  end
end
