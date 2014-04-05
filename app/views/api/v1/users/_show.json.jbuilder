# Partial for rendering one user
json.extract! user, :id, :login
works = user.works.visible_to_all.revealed.non_anon.to_a

# List a few works
json.works works.first(5) do |work|
    json.title work.title
    json.url   work_url(work)
end
