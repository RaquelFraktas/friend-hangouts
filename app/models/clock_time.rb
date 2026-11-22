# Wall-clock helpers. Windows are stored as minutes after local midnight in the
# hangout's time zone, so the planner can do integer interval math.
module ClockTime
  module_function

  def parse(value)
    return nil if value.blank?
    h, m = value.to_s.split(":").map(&:to_i)
    return nil if h.nil? || h > 23 || m.to_i > 59
    h * 60 + m.to_i
  end

  def to_field(minutes)
    return nil if minutes.nil?
    format("%02d:%02d", minutes / 60, minutes % 60)
  end

  def label(minutes)
    h, m = minutes.divmod(60)
    suffix = h < 12 ? "am" : "pm"
    h12 = h % 12
    h12 = 12 if h12.zero?
    m.zero? ? "#{h12}#{suffix}" : format("%d:%02d%s", h12, m, suffix)
  end

  def range_label(start_minute, end_minute)
    "#{label(start_minute)}–#{label(end_minute)}"
  end

  def duration_label(minutes)
    h, m = minutes.divmod(60)
    [ (h.positive? ? "#{h}h" : nil), (m.positive? ? "#{m}m" : nil) ].compact.join(" ")
  end
end
