# Coordinates the workers. Every input change goes through here so the version
# bookkeeping lives in one place:
#
#   friend edit ──► bump friend.input_version
#               ├─► note changed? create ScoutRun(note_version) ─► ScoutJob
#               └─► bump hangout.plan_requested_version ─────────► PlanJob(version)
#
#   ScoutJob writes a suggestion only if the window's note_version still
#   matches and the condition is still pending, then calls friend_changed!
#   (no new scouts) so the shortlist shows the suggestion.
#
#   PlanJob publishes a PlannerRun only if its version is the newest requested
#   one; it rebuilds digests only for friends whose input_version moved.
#
# Jobs are enqueued after the surrounding transaction commits, so a worker can
# never pick up a version number whose data isn't visible yet.
module Orchestrator
  module_function

  # Call inside (or outside) the transaction that changed the friend's inputs.
  # `windows_to_scout` are windows whose note changed and now need a scout.
  def friend_changed!(friend, reason:, windows_to_scout: [])
    ActiveRecord::Base.transaction do
      # Lock order is always hangout → friend (PlanJob does the same), so
      # concurrent edits and planner runs can't deadlock.
      version = bump_plan_version!(friend.hangout)
      friend.lock!
      friend.update!(input_version: friend.input_version + 1, responded_at: friend.responded_at || Time.current)

      runs = windows_to_scout.select { _1.condition_status == "pending" }.map do |window|
        ScoutRun.create!(hangout: friend.hangout, friend: friend, availability_window: window,
                         note_version: window.note_version, note_snapshot: window.note, status: "queued")
      end

      ActiveRecord.after_all_transactions_commit do
        runs.each { ScoutJob.perform_later(_1.id) }
        PlanJob.perform_later(friend.hangout_id, version, "#{friend.name}: #{reason}")
      end
    end
  end

  # Organizer setting changes or a manual "recompute" button.
  def hangout_changed!(hangout, reason:)
    ActiveRecord::Base.transaction do
      version = bump_plan_version!(hangout)
      ActiveRecord.after_all_transactions_commit { PlanJob.perform_later(hangout.id, version, reason) }
    end
  end

  def bump_plan_version!(hangout)
    hangout.lock!
    hangout.update!(plan_requested_version: hangout.plan_requested_version + 1)
    hangout.plan_requested_version
  end
end
