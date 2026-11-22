module ApplicationHelper
  def day_label(date) = date.strftime("%a, %b %-d")
  def time_range(start_minute, end_minute) = ClockTime.range_label(start_minute, end_minute)

  def local_time(hangout, time)
    return "—" if time.nil?
    time.in_time_zone(hangout.zone).strftime("%-l:%M:%S %P %Z, %b %-d")
  end

  def answer_chip(answer, text = nil)
    label = text || { "yes" => "Yes", "maybe" => "Maybe", "no" => "No", "unknown" => "Unknown" }.fetch(answer, answer)
    tag.span(label, class: "chip chip-#{answer}")
  end

  def status_chip(status)
    labels = {
      "queued" => "queued", "running" => "running", "suggested" => "suggested",
      "needs_review" => "needs review", "discarded_stale" => "discarded (stale)", "failed" => "failed",
      "pending" => "scout running", "confirmed" => "confirmed", "none" => "no note"
    }
    tag.span(labels.fetch(status, status), class: "chip chip-status-#{status}")
  end

  def condition_source_label(window)
    { "scout" => "confirmed scout suggestion", "friend" => "set by friend", "seed" => "pre-confirmed in seed data" }
      .fetch(window.condition_source.to_s, "confirmed")
  end
end
