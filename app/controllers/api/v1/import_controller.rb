class Api::V1::ImportController < Api::V1::BaseController
  respond_to :json

  # Imports multiple works with their meta from external URLs
  # Params:
  # +params+:: a JSON object containing the login of an archivist and an array of works
  def create
    archivist = User.find_by_login(params[:archivist])
    external_works = params[:works]
    results = ""
    if archivist && archivist.is_archivist?
      external_works.each do |work|
        urls = work[:chapter_urls]
        if urls.length > 0 && urls.length < ArchiveConfig.IMPORT_MAX_WORKS_BY_ARCHIVIST
          storyparser = StoryParser.new
          options = options(archivist, work)
          @work = storyparser.download_and_parse_chapters_into_story(urls, options)
          @work.save
        else
          results << "No URLs were provided for a work"
        end
      end
      # send_external_invites(@works)
      render status: :ok, json: {success: true, results: results}
    else
      render status: :forbidden, json: {success: false, errors: 'Only an archivist can import works through the API'}
    end
  end

private
  def options(archivist, params)
    {
      :archivist => archivist,
      :import_multiple => 'chapters',
      :importing_for_others => true,
      :do_not_set_current_author => true,
      :restricted => params[:restricted],
      :override_tags => params[:override_tags],
      :fandom => params[:fandoms],
      :warning => params[:warnings],
      :character => params[:characters],
      :rating => params[:rating],
      :relationship => params[:relationships],
      :category => params[:categories],
      :freeform => params[:additional_tags],
      :encoding => params[:encoding],
      :external_author_name => params[:external_author_name],
      :external_author_email => params[:external_author_email],
      :external_coauthor_name => params[:external_coauthor_name],
      :external_coauthor_email => params[:external_coauthor_email]
    }
  end
end