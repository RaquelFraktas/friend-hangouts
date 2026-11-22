class Friend < ApplicationRecord
  has_secure_token :invite_token, length: 32
  belongs_to :hangout
  has_many :availability_windows, -> { order(:date, :start_minute, :id) }, dependent: :destroy
  has_many :unavailable_days, -> { order(:date) }, dependent: :destroy
  has_many :scout_runs, dependent: :destroy

  validates :name, presence: true

  def responded? = responded_at.present?
  def unavailable_dates = unavailable_days.map(&:date)
  def unavailable_on?(date) = unavailable_days.any? { _1.date == date }

  def windows_on(date) = availability_windows.select { _1.date == date }

  def conflicting_windows
    dates = unavailable_dates
    availability_windows.select { dates.include?(_1.date) }
  end

  def unresolved_windows = availability_windows.select(&:condition_unresolved?)

  def latest_scout_run = scout_runs.max_by(&:id)
end
