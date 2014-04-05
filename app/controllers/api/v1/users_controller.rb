class Api::V1::UsersController < Api::V1::BaseController
  respond_to :json

  def index
    @users = User.first(5)
  end

  def show
    @user = User.find(params[:id])
    @works = @user.works.visible_to_all.revealed.non_anon.to_a
  end

end