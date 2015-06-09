class Import::Settings

  attr_reader :archivist, :do_not_set_current_author, :rating, :relationship, :language_id,
              :post_without_preview, :external_author_email, :external_coauthor_name, :encoding,
              :importing_for_others, :restricted, :override_tags, :character,
              :external_coauthor_email, :fandom, :external_author_name, :freeform,
              :import_multiple, :warning, :category, :pseuds

  def initialize(params)
    # Archiving parameters
    # a list of pseuds to set as authors
    @pseuds           = params[:pseuds_to_apply]

    @archivist        = params[:archivist]

    # true means do not save the current user as an author
    @do_not_set_current_author = params[:do_not_set_current_author]

    @import_multiple = params[:import_multiple]

    # if true, mark the story as posted without previewing
    @post_without_preview = params[:post_without_preview] == "1"

    # true means try and add external author for the work
    @importing_for_others = params[:importing_for_others] == "1"

    # true means restrict to logged-in AO3 users
    @restricted = params[:restricted] == "1"

    # set tag values even if some were parsed out of the work
    @override_tags = params[:override_tags] == "1"

    # Work parameters
    @fandom = params[:work][:fandom_string]
    @warning = params[:work][:warning_strings]
    @character = params[:work][:character_string]
    @rating = params[:work][:rating_string]
    @relationship = params[:work][:relationship_string]
    @category = params[:work][:category_string]
    @freeform = params[:work][:freeform_string]
    @encoding = params[:encoding]
    @external_author_name = params[:external_author_name]
    @external_author_email = params[:external_author_email]
    @external_coauthor_name = params[:external_coauthor_name]
    @external_coauthor_email = params[:external_coauthor_email]
    @language_id = params[:language_id]
  end

end
