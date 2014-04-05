# Include count of listed objects
json.total_count @works.to_a.count

# List minimal work information
json.works @works do |work|
  json.partial! 'blurb', work: work
end