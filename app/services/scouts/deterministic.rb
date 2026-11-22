module Scouts
  # Rule-based scout that recognizes a handful of phrases. Pure function of the
  # note text, so the seeded demo produces identical results on every run.
  class Deterministic
    AREA_PATTERN = /\b(manhattan|brooklyn|queens|(?:the\s+)?bronx|staten\s+island)\b/i
    AREA_LIST = /#{AREA_PATTERN}(?:\s*(?:,|\/|or|and)\s*#{AREA_PATTERN})*/i

    ONLY_AFTER   = /\b(?<list>#{AREA_LIST})\s+only\b/i
    ONLY_BEFORE  = /\bonly\s+(?:in\s+)?(?<list>#{AREA_LIST})/i
    EXCLUDE      = /\b(?:not|no|anywhere\s+but|except|avoid)\s+(?:in\s+)?(?<list>#{AREA_LIST})/i
    PREFERENCE   = /\b(?:prefer(?:ably)?|ideally|maybe|near|around|close\s+to|in)\s+(?<list>#{AREA_LIST})/i

    ACCESSIBLE   = /\b(wheelchair(?:[-\s]accessible)?|step[-\s]free|accessible|no\s+stairs)\b/i
    OUTDOOR      = /\b(outdoors?|outside|open[-\s]air)\b/i
    INDOOR       = /\b(indoors?|inside)\b/i
    CHEAP        = /\b(cheap|budget|inexpensive|low[-\s]cost)\b/i
    UNDER_PRICE  = /\bunder\s+\$(?<amount>\d+)\b/i
    TIME_WORDS   = /\b(\d{1,2}(:\d{2})?\s*(am|pm)|after\s+\d|before\s+\d|until\s+\d|by\s+\d|late|early|leave|leaving)\b/i

    FILLER = %w[only please pls ok okay fine is are and or but a the in for me i'm im prefer no not if
                anything anywhere works work good great thanks venue place spot].freeze

    def name = "deterministic-v1"

    def interpret(note, context: Context.default)
      text = note.to_s.squish
      return Result.new(status: :suggested, condition: Condition.new, explanation: "Empty note.") if text.empty?

      consumed = text.dup
      attrs = { areas: [], exclude_areas: [], max_price: nil, accessible: false, setting: nil }
      reasons = []
      review = []

      # Order matters: explicit exclusions/requirements before soft preferences.
      scan(consumed, EXCLUDE) { |m| attrs[:exclude_areas] += areas_in(m[:list]) }
      scan(consumed, ONLY_AFTER) { |m| attrs[:areas] += areas_in(m[:list]) }
      scan(consumed, ONLY_BEFORE) { |m| attrs[:areas] += areas_in(m[:list]) }
      reasons << "“only” makes the area a requirement" if attrs[:areas].any?
      reasons << "explicitly rules out an area" if attrs[:exclude_areas].any?

      preferred = []
      scan(consumed, PREFERENCE) { |m| preferred += areas_in(m[:list]) }
      if preferred.any? && attrs[:areas].empty?
        attrs[:areas] = preferred
        review << "mentions #{preferred.join('/')} without “only” — is it a requirement or a preference?"
      end

      if (overlap = attrs[:areas] & attrs[:exclude_areas]).any?
        review << "both requires and rules out #{overlap.join('/')}"
      end

      scan(consumed, ACCESSIBLE) { attrs[:accessible] = true }
      reasons << "asks for step-free access" if attrs[:accessible]

      outdoor = indoor = false
      scan(consumed, OUTDOOR) { outdoor = true }
      scan(consumed, INDOOR) { indoor = true }
      if outdoor && indoor
        review << "mentions both indoor and outdoor"
      elsif outdoor || indoor
        attrs[:setting] = outdoor ? "outdoor" : "indoor"
        reasons << "asks for an #{attrs[:setting]} venue"
      end

      scan(consumed, CHEAP) { attrs[:max_price] = 1 }
      scan(consumed, UNDER_PRICE) do |m|
        amount = m[:amount].to_i
        attrs[:max_price] = amount <= 20 ? 1 : (amount <= 50 ? 2 : 3)
      end
      reasons << "sets a budget" if attrs[:max_price]

      review << "times come from the start/end fields, not the note" if text.match?(TIME_WORDS)

      leftover = consumed.downcase.scan(/[a-z']+/) - FILLER
      condition = Condition.new(**attrs)

      if condition.empty? && review.empty?
        return Result.new(status: :needs_review, condition: condition,
                          explanation: "Couldn't find a supported venue condition in “#{text}”. " \
                                       "Pick one, or mark it as just a note.")
      end
      review << "didn't understand “#{leftover.uniq.join(' ')}”" if leftover.any?

      if review.any?
        Result.new(status: :needs_review, condition: condition,
                   explanation: "Needs review: #{review.join('; ')}.")
      else
        Result.new(status: :suggested, condition: condition,
                   explanation: "Read as “#{condition.describe}” (#{reasons.join(', ')}).")
      end
    end

    private

    # Yields each match and blanks it out of `text` so leftovers can be detected.
    def scan(text, pattern)
      while (match = pattern.match(text))
        yield match
        text[match.begin(0)...match.end(0)] = " " * (match.end(0) - match.begin(0))
      end
    end

    def areas_in(list)
      list.to_s.scan(AREA_PATTERN).flatten.map do |raw|
        word = raw.squish.downcase.sub(/\Athe\s+/, "")
        Condition::AREAS.find { _1.downcase == word }
      end.compact.uniq
    end
  end
end
