class PlannerRun < ApplicationRecord
  belongs_to :hangout

  def rebuilt_friends = hangout.friends.select { rebuilt_friend_ids.include?(_1.id) }
  def reused_friends = hangout.friends.select { reused_friend_ids.include?(_1.id) }
end
