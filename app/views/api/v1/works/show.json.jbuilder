# Include blurb
json.partial! 'blurb', work: @work

# Include contents as well
json.partial! 'chapters', work: @work