class Api::V2::WorksController < Api::V2::BaseController
  respond_to :json

  # POST - search for works based on imported url first, or based on any other provided work details
  def search
    work_searches = params[:works]
    messages = []

    status = error_status(work_searches)
    messages << work_searches_errors(status) unless status == :ok

    results = work_searches&.map { |metadata| find_existing_works(metadata.permit!) }

    messages << results.flatten.map { |r| r[:messages] }.flatten

    render_api_response(status, messages.flatten, works: results.flatten)
  end

  # POST - create a work and invite authors to claim
  def create
    archivist = User.find_by(login: params[:archivist])
    external_works = params[:items] || params[:works]
    works_responses = []

    # check for top-level errors (not an archivist, no works...)
    status, messages = batch_errors(archivist, external_works)

    if status == :ok
      # Process the works, updating the flags
      works_responses = external_works.map { |external_work| import_work(archivist, external_work.merge(params.permit!)) }
      success_responses, error_responses = works_responses.partition { |r| [:ok, :created, :found].include?(r[:status]) }

      # Send claim notification emails for successful works
      if params[:send_claim_emails] && success_responses.present?
        notified_authors = notify_and_return_authors(success_responses.map { |r| r[:work] }, archivist)
        messages << "Claim emails sent to #{notified_authors.to_sentence}."
      end

      # set final status code and message depending on the flags
      status = :bad_request if error_responses.present?
      messages = import_response_message(messages, success_responses.present?, error_responses.present?)
    end
    render_api_response(status, messages, works: works_responses.map { |r| r.except!(:work) })
  end

  private

  # Set messages based on success and error flags
  def import_response_message(messages, any_success, any_errors)
    messages << if any_success && any_errors
                  "At least one work was not imported. Please check individual work responses for further information."
                elsif !any_success && any_errors
                  "None of the works were imported. Please check individual work responses for further information."
                else
                  "All works were successfully imported."
                end
    messages
  end

  def error_status(requests)
    if requests.nil? || requests.empty?
      :empty_request
    elsif requests.length >= ArchiveConfig.IMPORT_MAX_CHAPTERS
      :too_many_requests
    else
      :ok
    end
  end

  def work_searches_errors(error_status)
    case error_status
      when :empty_request
        "Please provide a list of works to find."
      when :too_many_requests
        "Please provide no more than #{ ArchiveConfig.IMPORT_MAX_CHAPTERS } works to find."
      else
        "An unexpected error occurred: #{error_status}"
    end
  end

  def original_url_errors(error_status)
    case error_status
      when :empty_request
        "Please provide a list of URLs to find."
      when :too_many_requests
        "Please provide no more than #{ ArchiveConfig.IMPORT_MAX_CHAPTERS } URLs to find."
      else
        "An unexpected error occurred: #{error_status}"
    end
  end

  # Work-level error handling for requests that are incomplete or too large
  def work_errors(work)
    errors = []
    urls = work[:chapter_urls]
    status = error_status(urls)

    if status == :empty_request
      errors << "This work doesn't contain chapter_urls. Works can only be imported from publicly-accessible URLs."
    elsif status == :too_many_requests
      errors << "This work contains too many chapter URLs. A maximum of #{ArchiveConfig.IMPORT_MAX_CHAPTERS} " \
                  "chapters can be imported per work."
    end

    [status, errors]
  end

  # Search for works imported from the provided metadata objects
  def find_existing_works(metadata)
    results = []
    messages = []
    # Search for works - there may be duplicates and if there are multiple urls
    search_results = find_work_by_metadata(metadata)

    if search_results[:works].empty?
      results << { status: :not_found,
                   original_search: metadata,
                   messages: [search_results[:error]] }
    else
      work_results = search_results[:works].map do |work|
          archive_url = work_url(work)

          message = "Work \"#{work.title}\" created on #{work.created_at.to_date.to_s(:iso_date)} was found at \"#{archive_url}\"."
messages << message

          {
            work_search: metadata,
            archive_url: archive_url,
          created: work.created_at,
          message: message
          }
      end

      results << { status: :found,
                   original_search: metadata,
                   search_results: work_results.flatten,
                   messages: messages
      }
    end
    results
  end

  def find_work_by_import_url(original_url)
    works = nil
    if original_url.blank?
      message = "Please provide the original URL for the work."
    else
      # We know the url will be identical no need for a call to find_by_url
      works = Work.where(imported_from_url: original_url)
      message = if works.empty?
                  "No work has been imported from \"" + original_url + "\"."
                else
                  "Found #{works.size} work(s) imported from \"" + original_url + "\"."
                end
    end
    {
      original_url: original_url,
      works: works,
      message: message
    }
  end

  def find_work_by_metadata(metadata)
    error = ""
    if metadata[:original_urls].blank?
      title = metadata[:title]
      # pseud = metadata[:author]
      works = Work.where(title: title)
    else
      # We know the url will be identical no need for a call to find_by_url
      works = Work.where(imported_from_url: metadata[:original_urls]&.map { |u| u[:url] })
    end

    if works.to_a.empty?
      error = "No works match title: \"#{metadata[:title]}\", author: \"#{metadata[:pseud]}."
    end

    {
      original_url: metadata[:original_urls],
      works: works.to_a.select(&:present?),
      error: error
    }
  end

  # Use the story parser to scrape works from the chapter URLs
  def import_work(archivist, external_work)
    work_status, work_messages = work_errors(external_work)
    work_url = ""
    original_url = ""
    if work_status == :ok
      urls = external_work[:chapter_urls]
      original_url = urls.first
      storyparser = StoryParser.new
      options = story_parser_options(archivist, external_work)
      begin
        response = storyparser.import_chapters_into_story(urls, options)
        work = response[:work]
        work_status = response[:status]

        work.save if work_status == :created
        work_url = work_url(work)
        work_messages << response[:message]
      rescue => exception
        Rails.logger.error("------- API v2: error: #{exception.inspect}")
        work_status = :unprocessable_entity
        work_messages << "Unable to import this work."
        work_messages << exception.message
      end
    end

    {
      status: work_status,
      archive_url: work_url,
      original_id: external_work[:id],
      original_url: original_url,
      messages: work_messages,
      work: work
    }
  end

  # Send invitations to external authors for a given set of works
  def notify_and_return_authors(success_works, archivist)
    notified_authors = []
    external_authors = success_works.map(&:external_authors).flatten.uniq
    external_authors&.each do |external_author|
      external_author.find_or_invite(archivist)
      # One of the external author pseuds is its email address so filter that one out
      author_names = external_author.names.reject { |a| a.name == external_author.email }.map(&:name).flatten.join(", ")
      notified_authors << author_names
    end
    notified_authors
  end

  # Request and response hashes

  # Create options map for StoryParser
  def story_parser_options(archivist, work_params)
    {
      archivist: archivist,
      import_multiple: "chapters",
      importing_for_others: true,
      do_not_set_current_author: true,
      post_without_preview: work_params[:post_without_preview].blank? ? true : work_params[:post_without_preview],
      restricted: work_params[:restricted],
      override_tags: work_params[:override_tags].nil? ? true : work_params[:override_tags],
      detect_tags: work_params[:detect_tags].nil? ? true : work_params[:detect_tags],
      collection_names: work_params[:collection_names],
      title: work_params[:title],
      fandom: work_params[:fandoms],
      warning: work_params[:warnings],
      character: work_params[:characters],
      rating: work_params[:rating],
      relationship: work_params[:relationships],
      category: work_params[:categories],
      freeform: work_params[:additional_tags],
      language_id: Language.find_by(short: work_params[:language_code])&.id,
      summary: work_params[:summary],
      notes: work_params[:notes],
      encoding: work_params[:encoding],
      external_author_name: work_params[:external_author_name],
      external_author_email: work_params[:external_author_email],
      external_coauthor_name: work_params[:external_coauthor_name],
      external_coauthor_email: work_params[:external_coauthor_email]
    }
  end
end
