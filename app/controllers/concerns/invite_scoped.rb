module InviteScoped
  extend ActiveSupport::Concern

  included do
    before_action :load_friend
  end

  private

  def load_friend
    @friend = Friend.includes(:hangout).find_by(invite_token: params[:token].to_s) or raise ActionController::RoutingError, "Not Found"
    @hangout = @friend.hangout
  end

  def invite_page(**opts) = redirect_to(invite_path(@friend.invite_token, anchor: opts.delete(:anchor)), **opts)

  def render_invite_page(status: :unprocessable_entity)
    @friend.availability_windows.reset
    @new_window ||= @friend.availability_windows.build(date: @hangout.starts_on, status: "yes")
    render "invites/show", status: status
  end
end
