class Api::V1::ImportController < Api::V1::BaseController
  respond_to :json

  def create
    archivist = User.find_by_login(params[:archivist])

    if archivist && archivist.is_archivist?
      if params[:urls]
        storyparser = StoryParser.new
        results = storyparser.import_from_urls(params[:urls], options(params))
        render status: :ok, json: {success: true, urls: params[:urls], options: options(params), results: results}
      else
        render status: :unprocessable_entity, json: {success: false, errors: 'No URLs were provided for importing' }
      end
    else
      render status: :forbidden, json: {success: false, errors: 'Only an archivist can import works through the API'}
    end
  end

private
  def options(params)
    {
            #:pseuds => pseuds_to_apply,
            :importing_for_others => true,
            :restricted => params[:restricted],
            :override_tags => params[:override_tags],
            :fandom => params[:work][:fandoms],
            :warning => params[:work][:warnings],
            :character => params[:work][:characters],
            :rating => params[:work][:rating],
            :relationship => params[:work][:relationships],
            :category => params[:work][:categories],
            :freeform => params[:work][:additional_tags],
            :encoding => params[:encoding],
            :external_author_name => params[:external_author_name],
            :external_author_email => params[:external_author_email],
            :external_coauthor_name => params[:external_coauthor_name],
            :external_coauthor_email => params[:external_coauthor_email]
        }
  end
end