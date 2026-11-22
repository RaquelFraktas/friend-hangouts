# Pure-Ruby planner. Takes the hangout settings, one digest per friend, and the
# venue catalog, and returns a ranked shortlist of up to three options.
#
# Candidate slots: for every date, each pair of window boundaries (s, e) with
# e - s >= min duration is a possible slot. A friend counts only if one of
# their windows covers the *entire* slot. For a given set of attendees we keep
# only the longest slot (the intersection of their windows).
#
# Ranking (each step only breaks ties left by the previous one):
#   1. most confirmed Yes
#   2. most "could attend" (Yes + Maybe, incl. Yes with an unresolved condition)
#   3. fewest unresolved conditions
#   4. earliest date, then earliest start time
#   5. longest slot
#   6. venue name A→Z
# Within a slot, the venue is chosen by steps 1, 2, 3 and 6.
# Options must not overlap in time on the same date, so the shortlist is
# genuinely three different times.
class Planner
  SHORTLIST_SIZE = 3

  # Builds the planner-ready digest for one friend. Cached on the friend row
  # by input_version so a replan reuses unchanged friends.
  def self.digest_for(friend)
    unavailable = friend.unavailable_dates
    {
      "friend_id" => friend.id,
      "name" => friend.name,
      "responded" => friend.responded?,
      "unavailable_dates" => unavailable.map(&:iso8601),
      "windows" => friend.availability_windows.map do |w|
        {
          "id" => w.id,
          "date" => w.date.iso8601,
          "start" => w.start_minute,
          "end" => w.end_minute,
          "status" => w.status,
          "note" => w.note,
          "condition_status" => w.condition_status,
          "condition" => w.confirmed_condition&.to_h,
          "suggested" => w.suggested_condition,
          # A window on a day the friend also marked unavailable is ignored
          # until they resolve the conflict.
          "conflict" => unavailable.include?(w.date)
        }
      end
    }
  end

  Slot = Data.define(:date, :start, :end) do
    def duration = self.end - start
    def overlaps?(other) = date == other.date && start < other.end && other.start < self.end
  end

  def initialize(hangout:, digests:, venues:)
    @hangout = hangout
    @digests = digests
    @venues = venues.sort_by(&:name)
    @min = hangout.min_duration_minutes
  end

  def candidate_slots
    @candidate_slots ||= @hangout.dates.flat_map { candidate_slots_on(_1) }
  end

  def shortlist
    evaluated = candidate_slots.map { best_option_for(_1) }.compact
    ranked = evaluated.sort_by { rank_key(_1) }
    picked = []
    ranked.each do |option|
      next if picked.any? { _1[:slot].overlaps?(option[:slot]) }
      picked << option
      break if picked.size == SHORTLIST_SIZE
    end
    picked.each_with_index.map { |option, i| serialize(option, i + 1, ranked) }
  end

  private

  def usable_windows(digest, date)
    iso = date.iso8601
    digest["windows"].select { _1["date"] == iso && !_1["conflict"] }
  end

  def candidate_slots_on(date)
    windows = @digests.flat_map { usable_windows(_1, date) }
    points = windows.flat_map { [ _1["start"], _1["end"] ] }.uniq.sort
    by_attendees = {}
    points.combination(2).each do |s, e|
      next if e - s < @min
      slot = Slot.new(date: date, start: s, end: e)
      attendees = @digests.map { |d| covering_window(d, slot)&.dig("id") }
      next if attendees.compact.empty?
      key = attendees
      by_attendees[key] = slot if by_attendees[key].nil? || slot.duration > by_attendees[key].duration
    end
    by_attendees.values
  end

  # Prefer a resolved Yes over anything else if several windows cover the slot.
  def covering_window(digest, slot)
    usable_windows(digest, slot.date)
      .select { _1["start"] <= slot.start && _1["end"] >= slot.end }
      .min_by { [ _1["status"] == "yes" ? 0 : 1, unresolved?(_1) ? 1 : 0, _1["id"] ] }
  end

  def unresolved?(window) = AvailabilityWindow::UNRESOLVED_CONDITION_STATUSES.include?(window["condition_status"])

  # Classifies one friend for a slot at a venue.
  def attendance(digest, slot, venue)
    base = { friend_id: digest["friend_id"], name: digest["name"] }
    window = covering_window(digest, slot)

    if window.nil?
      if digest["unavailable_dates"].include?(slot.date.iso8601)
        return base.merge(answer: "no", reason: "marked the day unavailable")
      end
      reason = if !digest["responded"]
        "hasn't responded"
      elsif (partial = partial_window(digest, slot))
        "only free #{ClockTime.range_label(partial['start'], partial['end'])}"
      else
        "left this time blank"
      end
      return base.merge(answer: "unknown", reason: reason)
    end

    if unresolved?(window)
      return base.merge(answer: "maybe", unresolved: true, note: window["note"],
                        reason: "#{window['status'] == 'yes' ? 'Yes' : 'Maybe'} pending condition “#{window['note']}”")
    end

    if (condition = Condition.from_h(window["condition"]))
      failures = condition.failures_for(venue)
      return base.merge(answer: "no", reason: failures.join(", ")) if failures.any?
    end

    base.merge(answer: window["status"])
  end

  def partial_window(digest, slot)
    usable_windows(digest, slot.date).find { _1["start"] < slot.end && slot.start < _1["end"] }
  end

  def best_option_for(slot)
    options = @venues.map do |venue|
      people = @digests.map { attendance(_1, slot, venue) }
      { slot: slot, venue: venue, people: people, counts: count(people) }
    end
    options.select { _1[:counts]["yes"] + _1[:counts]["maybe"] > 0 }
           .min_by { venue_key(_1) }
           &.merge(venue_alternatives: options)
  end

  def count(people)
    counts = %w[yes maybe no unknown].index_with { 0 }
    people.each { counts[_1[:answer]] += 1 }
    counts["unresolved"] = people.count { _1[:unresolved] }
    counts
  end

  def venue_key(option)
    c = option[:counts]
    [ -c["yes"], -(c["yes"] + c["maybe"]), c["unresolved"], option[:venue].name ]
  end

  def rank_key(option)
    c = option[:counts]
    s = option[:slot]
    [ -c["yes"], -(c["yes"] + c["maybe"]), c["unresolved"], s.date, s.start, -s.duration, option[:venue].name ]
  end

  def serialize(option, rank, ranked)
    slot, venue, counts, people = option.values_at(:slot, :venue, :counts, :people)
    total = @digests.size
    {
      "rank" => rank,
      "date" => slot.date.iso8601,
      "start" => slot.start,
      "end" => slot.end,
      "venue_id" => venue.id,
      "venue_name" => venue.name,
      "venue_summary" => venue.summary,
      "counts" => counts,
      "total" => total,
      "all_confirmed" => counts["yes"] == total,
      "all_could_attend" => counts["yes"] + counts["maybe"] == total,
      "people" => people.map(&:stringify_keys),
      "unresolved" => people.select { _1[:unresolved] }.map { { "name" => _1[:name], "note" => _1[:note] } },
      "explanation" => explain(option, ranked)
    }
  end

  def explain(option, ranked)
    slot, venue, counts, people = option.values_at(:slot, :venue, :counts, :people)
    total = @digests.size
    lines = []
    lines << if counts["yes"] == total
      "Everyone is a confirmed Yes."
    elsif counts["yes"] + counts["maybe"] == total
      "All #{total} could make it, but only #{counts['yes']} are confirmed."
    else
      "#{counts['yes']} confirmed Yes."
    end

    gaps = people.reject { %w[yes].include?(_1[:answer]) }
    gaps.group_by { _1[:answer] }.each do |answer, group|
      label = { "maybe" => "Maybe", "no" => "Can't", "unknown" => "Unknown" }[answer]
      lines << "#{label}: #{group.map { "#{_1[:name]} (#{_1[:reason] || answer})" }.join(', ')}."
    end

    # Venue tradeoff: who would be lost at the next-best venue elsewhere?
    alternatives = option[:venue_alternatives].reject { _1[:venue] == venue }
    worse = alternatives.select { _1[:counts]["yes"] < counts["yes"] }
    if worse.any? && worse.size == alternatives.size
      lines << "#{venue.name} is the only venue that works for everyone counted here."
    elsif worse.any?
      lines << "#{venue.name} satisfies everyone's venue conditions; #{worse.size} other venue(s) would lose someone."
    end

    tied = ranked.find { _1 != option && !_1[:slot].overlaps?(slot) && _1[:counts].values_at("yes", "maybe", "unresolved") == counts.values_at("yes", "maybe", "unresolved") }
    if tied
      order = [ tied[:slot].date, tied[:slot].start ] <=> [ slot.date, slot.start ]
      lines << "Ties on turnout with #{tied[:slot].date.strftime('%a')} #{ClockTime.range_label(tied[:slot].start, tied[:slot].end)}; " \
               "#{order.positive? ? 'ranked ahead because it is sooner' : 'ranked behind because it is later'}."
    end
    lines.join(" ")
  end
end
