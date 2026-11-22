class UnavailableDay < ApplicationRecord
  belongs_to :friend
  validates :date, presence: true, uniqueness: { scope: :friend_id }
  validate :within_hangout_range

  private

  def within_hangout_range
    return if date.blank? || friend.nil?
    errors.add(:date, "is outside the hangout dates") unless friend.hangout.covers_date?(date)
  end
end
