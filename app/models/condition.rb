# A venue condition the planner can evaluate, e.g. "Brooklyn only".
# Stored as JSON on AvailabilityWindow (suggested_condition / condition).
class Condition
  AREAS = [ "Manhattan", "Brooklyn", "Queens", "Bronx", "Staten Island" ].freeze
  SETTINGS = %w[indoor outdoor].freeze
  PRICE_LABELS = { 1 => "$", 2 => "$$", 3 => "$$$" }.freeze

  attr_reader :areas, :exclude_areas, :max_price, :accessible, :setting

  def self.from_h(hash)
    return nil if hash.blank?
    h = hash.to_h.stringify_keys
    new(
      areas: h["areas"],
      exclude_areas: h["exclude_areas"],
      max_price: h["max_price"],
      accessible: h["accessible"],
      setting: h["setting"]
    )
  end

  # Builds a condition from the friend's "correct it" form.
  def self.from_form(params)
    new(
      areas: Array(params[:areas]).reject(&:blank?),
      exclude_areas: Array(params[:exclude_areas]).reject(&:blank?),
      max_price: params[:max_price].presence,
      accessible: ActiveModel::Type::Boolean.new.cast(params[:accessible]),
      setting: params[:setting].presence
    )
  end

  def initialize(areas: [], exclude_areas: [], max_price: nil, accessible: false, setting: nil)
    @areas = Array(areas).map(&:to_s).select { AREAS.include?(_1) }.uniq.sort
    @exclude_areas = Array(exclude_areas).map(&:to_s).select { AREAS.include?(_1) }.uniq.sort
    @max_price = max_price.present? ? max_price.to_i.clamp(1, 3) : nil
    @accessible = accessible == true
    @setting = SETTINGS.include?(setting.to_s) ? setting.to_s : nil
  end

  def empty?
    areas.empty? && exclude_areas.empty? && max_price.nil? && !accessible && setting.nil?
  end

  def to_h
    {
      "areas" => areas, "exclude_areas" => exclude_areas, "max_price" => max_price,
      "accessible" => accessible, "setting" => setting
    }
  end

  def ==(other) = other.is_a?(Condition) && to_h == other.to_h

  # Returns the list of reasons the venue fails; empty means it satisfies the condition.
  def failures_for(venue)
    reasons = []
    reasons << "#{areas.join('/')} only" if areas.any? && !areas.include?(venue.area)
    reasons << "not #{venue.area}" if exclude_areas.include?(venue.area)
    reasons << "#{PRICE_LABELS[max_price]} or cheaper" if max_price && venue.price_level > max_price
    reasons << "needs step-free access" if accessible && !venue.accessible
    reasons << "#{setting} only" if setting && venue.setting != setting
    reasons
  end

  def satisfied_by?(venue) = failures_for(venue).empty?

  def describe
    return "No venue condition" if empty?
    parts = []
    parts << "#{areas.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')} only" if areas.any?
    parts << "not in #{exclude_areas.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')}" if exclude_areas.any?
    parts << "#{PRICE_LABELS[max_price]} or cheaper" if max_price
    parts << "step-free access" if accessible
    parts << "#{setting} venue" if setting
    parts.join(", ")
  end
end
