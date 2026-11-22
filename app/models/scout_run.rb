class ScoutRun < ApplicationRecord
  STATUSES = %w[queued running suggested needs_review discarded_stale failed].freeze

  belongs_to :hangout
  belongs_to :friend
  belongs_to :availability_window, optional: true

  validates :status, inclusion: { in: STATUSES }

  def finished? = %w[suggested needs_review discarded_stale failed].include?(status)
end
