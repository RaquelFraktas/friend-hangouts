# Recomputes the shortlist. Holds the hangout row lock while it reads inputs
# and publishes, and only publishes for the newest requested version:
#
#   version <  plan_requested_version  → a newer PlanJob is queued; skip.
#   version <= plan_computed_version   → duplicate/retry of published work; skip.
#
# Because input changes bump plan_requested_version on the same row (and wait
# for this lock), the inputs read here are exactly the ones for `version`.
class PlanJob < ApplicationJob
  queue_as :planner
  # Retries are left to Sidekiq (exponential backoff); every step is idempotent.

  def perform(hangout_id, version, trigger = nil)
    hangout = Hangout.find_by(id: hangout_id)
    return if hangout.nil?

    hangout.with_lock do
      return :superseded if version < hangout.plan_requested_version
      return :already_computed if version <= hangout.plan_computed_version

      friends = hangout.friends.includes(:availability_windows, :unavailable_days).to_a
      rebuilt, reused = friends.partition { _1.digest_version != _1.input_version || _1.digest.nil? }
      rebuilt.each { _1.update_columns(digest: Planner.digest_for(_1), digest_version: _1.input_version) }

      planner = Planner.new(hangout: hangout, digests: friends.map(&:digest), venues: Venue.all.to_a)
      hangout.planner_runs.create!(
        version: version,
        trigger: trigger,
        options: planner.shortlist,
        candidate_count: planner.candidate_slots.size,
        rebuilt_friend_ids: rebuilt.map(&:id),
        reused_friend_ids: reused.map(&:id),
        input_versions: friends.to_h { [ _1.id.to_s, _1.input_version ] },
        computed_at: Time.current
      )
      hangout.update!(plan_computed_version: version)
      :published
    end
  end
end
