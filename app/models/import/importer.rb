class Import::Importer
  include I18n

  def initialize(import_settings)
    @settings = Import::Settings.new(import_settings)
  end

  def import(urls)
    options = @settings.instance_values.symbolize_keys

    storyparser = Import::StoryParser.new
    works = []
    errors = {}
    if @settings.import_multiple == "works" && urls.length > 1
      works, failed_urls, errors = storyparser.import_from_urls(urls, options)
      unless failed_urls.empty?
        errors = failed_urls.zip(errors).to_h
      end
    else # a single work possibly with multiple chapters
      begin
        if urls.size == 1
          work = storyparser.download_and_parse_story(urls.first, options)
        else
          work = storyparser.download_and_parse_chapters_into_story(urls, options)
        end
        works << work
        unless work && work.save
          errors[urls.first] = I18n::ts("We were only partially able to import this work and couldn't save it. Please review below!")
        end
      rescue Timeout::Error
        errors[urls.first] = I18n::ts("Import has timed out. This may be due to connectivity problems with the source site. Please try again in a few minutes, or check Known Issues to see if there are import problems with this site.")
      rescue Import::StoryParser::Error => exception
        errors[urls.first] = I18n::ts("We couldn't successfully import that work, sorry: %{message}", :message => exception.message)
      end
    end

    [works, errors]
  end

end