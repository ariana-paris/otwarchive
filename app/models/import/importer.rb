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
          errors[urls.first] = ts("We were only partially able to import this work and couldn't save it. Please review below!")
        end
      rescue Timeout::Error
        errors[urls.first] = ts("Import has timed out. This may be due to connectivity problems with the source site. Please try again in a few minutes, or check Known Issues to see if there are import problems with this site.")
      rescue Import::StoryParser::Error => exception
        errors[urls.first] = ts("We couldn't successfully import that work, sorry: %{message}", :message => exception.message)
      end
    end

    [works, errors]
  end

  def check_errors(urls, current_user)
    if urls.nil? || urls.empty?
      return ts("Did you want to enter a URL?")
    end

    # is external author information entered when import for others is not checked?
    if (@settings.external_author_name.present? || @settings.external_author_email.present?) &&
      !@settings.importing_for_others
      return ts("You have entered an external author name or e-mail address but did not select \"Import for others.\" " +
         "Please select the \"Import for others\" option or remove the external author information to continue.")
    end

    # is this an archivist importing?
    if @settings.importing_for_others && !current_user.archivist
      return ts("You may not import stories by other users unless you are an approved archivist.")
    end

    # make sure we're not importing too many at once
    if @settings.import_multiple == 'works' &&
      (!current_user.archivist && urls.length > ArchiveConfig.IMPORT_MAX_WORKS ||
        urls.length > ArchiveConfig.IMPORT_MAX_WORKS_BY_ARCHIVIST)
      return ts("You cannot import more than %{max} works at a time.",
                max: current_user.archivist ? ArchiveConfig.IMPORT_MAX_WORKS_BY_ARCHIVIST : ArchiveConfig.IMPORT_MAX_WORKS)

    elsif @settings.import_multiple == 'chapters' && urls.length > ArchiveConfig.IMPORT_MAX_CHAPTERS
      return ts("You cannot import more than %{max} chapters at a time.",
         max: ArchiveConfig.IMPORT_MAX_CHAPTERS)
    end
  end

  # if we are importing for others, we need to send invitations
  def send_external_invites(works, current_user)
    return unless @settings.importing_for_others

    @external_authors = works.collect(&:external_authors).flatten.uniq
    if @external_authors.empty?
      I18n.ts("No authors to notify.")
    else
      @external_authors.each do |external_author|
        external_author.find_or_invite(current_user)
      end
      I18n.ts("We have notified the author(s) you imported works for. If any were missed, you can also add co-authors manually.")
    end
  end
end
