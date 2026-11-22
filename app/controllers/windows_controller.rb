class WindowsController < ApplicationController
  include InviteScoped
  before_action :load_window, only: %i[update destroy condition]

  def create
    @new_window = @friend.availability_windows.build(window_params)
    saved = AvailabilityWindow.transaction do
      next false unless @new_window.save
      Orchestrator.friend_changed!(@friend, reason: "added #{describe(@new_window)}", windows_to_scout: [ @new_window ])
      true
    end
    return invite_page(notice: "Added #{describe(@new_window)}.", anchor: "day-#{@new_window.date}") if saved

    render_invite_page
  end

  def update
    @window.assign_attributes(window_params)
    saved = AvailabilityWindow.transaction do
      next false unless @window.save
      scout = @window.saved_change_to_note_version? ? [ @window ] : []
      Orchestrator.friend_changed!(@friend, reason: "edited #{describe(@window)}", windows_to_scout: scout)
      true
    end
    return invite_page(notice: "Updated #{describe(@window)}.", anchor: "day-#{@window.date}") if saved

    @editing_window = @window
    render_invite_page
  end

  def destroy
    AvailabilityWindow.transaction do
      @window.destroy!
      Orchestrator.friend_changed!(@friend, reason: "removed #{describe(@window)}")
    end
    invite_page(notice: "Removed #{describe(@window)}.", anchor: "day-#{@window.date}")
  end

  # Friend confirms the scout's suggestion, corrects it, or says the note has
  # no venue condition. The form carries note_version so a confirmation made
  # from a stale page can't attach to a newer note.
  def condition
    if params[:note_version].to_i != @window.note_version
      return invite_page(alert: "Your note changed since that page loaded — please review the latest suggestion.",
                         anchor: "window-#{@window.id}")
    end

    attrs = case params[:decision]
    when "confirm"
      suggestion = @window.suggestion
      return invite_page(alert: "There's no suggestion to confirm yet.") if suggestion.nil? || @window.condition_status == "pending"
      { condition: suggestion.to_h, condition_source: "scout" }
    when "correct"
      { condition: Condition.from_form(params.fetch(:condition, {})).to_h, condition_source: "friend" }
    when "just_note"
      { condition: Condition.new.to_h, condition_source: "friend" }
    else
      return invite_page(alert: "Unknown choice.")
    end

    AvailabilityWindow.transaction do
      @window.lock!
      @window.update!(attrs.merge(condition_status: "confirmed"))
      Orchestrator.friend_changed!(@friend, reason: "confirmed “#{Condition.from_h(attrs[:condition]).describe}” for #{describe(@window)}")
    end
    invite_page(notice: "Thanks — saved “#{@window.confirmed_condition.describe}”.", anchor: "window-#{@window.id}")
  end

  private

  def load_window
    @window = @friend.availability_windows.find(params[:id])
  end

  def window_params
    params.require(:availability_window).permit(:date, :start_time, :end_time, :status, :note)
  end

  def describe(window)
    "#{window.date&.strftime('%a %b %-d')} #{window.start_minute && window.end_minute ? window.time_label : ''}".strip
  end
end
