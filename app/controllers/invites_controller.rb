class InvitesController < ApplicationController
  include InviteScoped

  def show
    @new_window = AvailabilityWindow.new(friend: @friend, date: params[:date].presence || @hangout.starts_on, status: "yes")
  end
end
