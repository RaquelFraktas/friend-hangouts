class DaysController < ApplicationController
  include InviteScoped

  def create
    date = parse_date
    day = @friend.unavailable_days.find_or_initialize_by(date: date)
    UnavailableDay.transaction do
      raise ActiveRecord::Rollback unless day.new_record? ? day.save : true
      Orchestrator.friend_changed!(@friend, reason: "marked #{date&.strftime('%a')} unavailable")
    end
    if day.persisted?
      invite_page(notice: "Marked #{date.strftime('%a %b %-d')} as unavailable.", anchor: "day-#{date}")
    else
      invite_page(alert: day.errors.full_messages.to_sentence)
    end
  end

  def destroy
    date = parse_date
    UnavailableDay.transaction do
      @friend.unavailable_days.where(date: date).destroy_all
      Orchestrator.friend_changed!(@friend, reason: "cleared #{date&.strftime('%a')} unavailable")
    end
    invite_page(notice: "#{date.strftime('%a %b %-d')} is no longer marked unavailable.", anchor: "day-#{date}")
  end

  private

  def parse_date
    Date.iso8601(params[:date].to_s)
  rescue Date::Error
    raise ActionController::BadRequest, "bad date"
  end
end
