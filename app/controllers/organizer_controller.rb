class OrganizerController < ApplicationController
  before_action :load_hangout

  def show
    @friends = @hangout.friends.includes(:availability_windows, :unavailable_days, :scout_runs).to_a
    @run = @hangout.latest_planner_run
    @recent_runs = @hangout.planner_runs.order(version: :desc).limit(6).to_a
    @scout_runs = @hangout.scout_runs.includes(:friend).order(id: :desc).limit(10).to_a
  end

  def update
    if @hangout.update(hangout_params)
      Orchestrator.hangout_changed!(@hangout, reason: "organizer updated settings")
      redirect_to organizer_path(@hangout.organizer_token), notice: "Settings saved. Recomputing the shortlist…"
    else
      show
      flash.now[:alert] = "Couldn't save settings."
      render :show, status: :unprocessable_entity
    end
  end

  def recompute
    Orchestrator.hangout_changed!(@hangout, reason: "organizer requested recompute")
    redirect_to organizer_path(@hangout.organizer_token), notice: "Recomputing…"
  end

  private

  def load_hangout
    @hangout = Hangout.find_by(organizer_token: params[:token].to_s) or raise ActionController::RoutingError, "Not Found"
  end

  def hangout_params
    params.require(:hangout).permit(:name, :starts_on, :ends_on, :min_duration_minutes, :time_zone)
  end
end
