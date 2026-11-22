# Interprets one note for one window. Safe to retry and safe to run late:
# it only writes when the window still has the note_version it was asked
# about AND the condition is still pending (never over a confirmation or
# a friend's correction).
class ScoutJob < ApplicationJob
  queue_as :scouts
  # Retries are left to Sidekiq (exponential backoff); every step is idempotent.

  def perform(scout_run_id)
    run = ScoutRun.find_by(id: scout_run_id)
    return if run.nil? || run.finished?

    scout = Scouts.current
    run.update!(status: "running", scout_name: scout.name, started_at: run.started_at || Time.current,
                attempts: run.attempts + 1)

    window = run.availability_window
    return discard(run, "window was removed") if window.nil?
    return discard(run, "note changed to v#{window.note_version}") if window.note_version != run.note_version

    result = scout.interpret(run.note_snapshot, context: Scouts::Context.default)

    applied = false
    window.with_lock do
      if window.note_version == run.note_version && window.condition_status == "pending"
        window.update!(condition_status: result.status.to_s, suggested_condition: result.condition.to_h,
                       scout_explanation: result.explanation)
        applied = true
      end
    end

    unless applied
      return discard(run, window.note_version != run.note_version ? "note changed while scouting" : "already resolved by friend")
    end

    run.update!(status: result.status.to_s, result: result.to_h, finished_at: Time.current)
    Orchestrator.friend_changed!(run.friend, reason: "scout #{result.status.to_s.tr('_', ' ')} “#{run.note_snapshot}”")
  rescue => e
    # Leave the run retryable and visible on the dashboard, then let Sidekiq retry.
    run&.update_columns(status: "queued", error: "retrying after #{e.class}: #{e.message}") if run&.persisted?
    raise
  end

  private

  def discard(run, why)
    run.update!(status: "discarded_stale", error: why, finished_at: Time.current)
  end
end
