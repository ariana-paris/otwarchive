# Include blurb
json.partial! 'blurb', work: @work

# Include contents
json.chapters @work.chapters.posted.order(:position) do |chapter|
  json.title          chapter.title
  json.position       chapter.position
  json.summary        chapter.summary
  json.notes          chapter.notes
  json.endnotes       chapter.endnotes
  json.content        chapter.content
  json.published_at   chapter.published_at
end