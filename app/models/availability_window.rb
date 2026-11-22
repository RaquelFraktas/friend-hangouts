# One block of availability a friend entered. The structured fields (date,
# start/end, yes/maybe) are the source of truth; the free-text note is only
# interpreted by a scout into a venue Condition.
class AvailabilityWindow < ApplicationRecord
  STATUSES = %w[yes maybe].freeze
  CONDITION_STATUSES = %w[none pending suggested needs_review confirmed].freeze
  UNRESOLVED_CONDITION_STATUSES = %w[pending suggested needs_review].freeze

  belongs_to :friend
  has_many :scout_runs, dependent: :nullify

  validates :date, presence: true
  validates :start_minute, :end_minute, presence: { message: "needs a time" }
  validates :status, inclusion: { in: STATUSES }
  validates :condition_status, inclusion: { in: CONDITION_STATUSES }
  validates :note, length: { maximum: 200 }
  validate :within_hangout_range
  validate :ends_after_start

  before_save :reset_condition_when_note_changes

  # Form-friendly "HH:MM" accessors in the hangout's time zone.
  def start_time = ClockTime.to_field(start_minute)
  def end_time = ClockTime.to_field(end_minute)
  def start_time=(value)
    self.start_minute = ClockTime.parse(value)
  end

  def end_time=(value)
    self.end_minute = ClockTime.parse(value)
  end

  def note=(value)
    super(value.to_s.squish.presence)
  end

  def duration_minutes = end_minute - start_minute
  def covers?(start_min, end_min) = start_minute <= start_min && end_minute >= end_min
  def time_label = ClockTime.range_label(start_minute, end_minute)

  def condition_unresolved? = UNRESOLVED_CONDITION_STATUSES.include?(condition_status)
  def confirmed_condition = condition_status == "confirmed" ? Condition.from_h(condition) : nil
  def suggestion = Condition.from_h(suggested_condition)

  def conflicts_with_unavailable_day? = friend.unavailable_on?(date)
  def outside_hangout_range? = !friend.hangout.covers_date?(date)

  private

  def within_hangout_range
    return if date.blank? || friend.nil?
    hangout = friend.hangout
    return if hangout.covers_date?(date)
    errors.add(:date, "must be between #{hangout.starts_on.strftime('%b %-d')} and #{hangout.ends_on.strftime('%b %-d')}")
  end

  def ends_after_start
    return if start_minute.nil? || end_minute.nil?
    errors.add(:end_time, "must be after the start time") if end_minute <= start_minute
  end

  # A changed note invalidates any earlier interpretation. note_version lets
  # in-flight scout jobs detect that they are now stale.
  def reset_condition_when_note_changes
    return unless new_record? || will_save_change_to_note?

    self.note_version = note_version.to_i + 1
    self.suggested_condition = nil
    self.condition = nil
    self.scout_explanation = nil
    self.condition_source = nil
    self.condition_status = note.present? ? "pending" : "none"
  end
end
