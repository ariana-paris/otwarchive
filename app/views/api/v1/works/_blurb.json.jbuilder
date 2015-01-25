json.extract! work, :id, :title, :summary, :notes, :endnotes, :complete, :restricted, :revised_at, :word_count

# Include creators
json.partial! 'creators', work: work

json.url                  api_v1_work_url(work)
json.comment_url          new_work_comment_url(work)
json.language             work.language.try(:name) || 'English'
json.chapters_posted      work.chapters.posted.count
json.chapters_expected    work.expected_number_of_chapters

# All the tags, returned as separate
work.tag_groups.each_pair do |type, tags|
  unless tags.blank?
    type = type.downcase.gsub(/freeform/, 'additional_tag').pluralize
    json.set! type, tags.map {|tag| {id: tag.id, name: tag.name}}
  end
end


json.series work.serial_works do |sw|
  json.title      sw.series.title
  json.position   sw.position
  json.url        series_url(sw.series)
end

json.collections work.approved_collections do |collection|
  json.title  collection.title
  json.url    collection_url(collection)
end

json.inspired_parents work.parent_work_relationships do |rw|
  json.title    rw.parent.title
  json.partial! 'creators', work: rw.parent
  json.url      url_for(action: :show, controller: rw.parent_type.underscore.pluralize, id: rw.parent_id, only_path: false)
end

json.inspired_children work.approved_related_works do |rw|
  json.title        rw.work.title
  json.partial! 'creators', work: rw.work
  json.translation  rw.translation?
  json.url          api_v1_work_url(rw.work)
end