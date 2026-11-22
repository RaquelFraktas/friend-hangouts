class Hangout < ApplicationRecord
  DEFAULT_TIME_ZONE = "America/New_York"

  has_secure_token :organizer_token, length: 32
  has_many :friends, -> { order(:position, :id) }, dependent: :destroy
  has_many :availability_windows, through: :friends
  has_many :scout_runs, dependent: :destroy
  has_many :planner_runs, dependent: :destroy

  validates :name, presence: true
  validates :starts_on, :ends_on, presence: true
  validates :min_duration_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 15, less_than_or_equal_to: 24 * 60 }
  validates :time_zone, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map { _1.tzinfo.name }.uniq } }
  validate :range_order

  attribute :time_zone, default: DEFAULT_TIME_ZONE

  def dates = (starts_on..ends_on).to_a
  def covers_date?(date) = date.present? && date.between?(starts_on, ends_on)
  def zone = ActiveSupport::TimeZone[time_zone]
  def zone_abbreviation = zone.now.strftime("%Z")

  def latest_planner_run = planner_runs.order(version: :desc).first
  def plan_pending? = plan_requested_version > plan_computed_version

  private

  def range_order
    return if starts_on.blank? || ends_on.blank?
    errors.add(:ends_on, "must be on or after the start date") if ends_on < starts_on
    errors.add(:ends_on, "must be within 31 days of the start date") if (ends_on - starts_on) > 31
  end
end
