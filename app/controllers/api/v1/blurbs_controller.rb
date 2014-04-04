class Api::V1::BlurbsController < Api::V1::BaseController
  respond_to :json
  
  def show
    @work = Work.find(params[:id])
    respond_with @work.summary
  end

end