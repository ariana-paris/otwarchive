# Include count of listed objects
#json.total_count @total
#json.total_pages @pages

# List minimal work information
json.array!(@works) do |work|
  json.partial! 'blurb', work: work
end