# Scouts interpret a friend's free-text note into a venue Condition.
#
# Interface (all a replacement scout must implement):
#
#   scout.name                              # => "deterministic-v1"
#   scout.interpret(note, context:)         # => Scouts::Result
#
# `context` is a Scouts::Context describing what the planner can evaluate
# (known areas, settings, price levels), so an LLM-backed scout can be prompted
# with the supported vocabulary and asked to return the same Result shape.
#
# Swap the implementation with `config.x.scout_class = "Scouts::MyLlmScout"`.
module Scouts
  STATUSES = %i[suggested needs_review].freeze

  # status:      :suggested (confident) or :needs_review (ambiguous/unsupported)
  # condition:   Condition (may be empty: "this note has no venue condition")
  # explanation: short human-readable reasoning shown next to the note
  Result = Data.define(:status, :condition, :explanation) do
    def initialize(status:, condition:, explanation:)
      raise ArgumentError, "unknown scout status #{status}" unless STATUSES.include?(status)
      super
    end

    def to_h = { "status" => status.to_s, "condition" => condition&.to_h, "explanation" => explanation }
  end

  Context = Data.define(:areas, :settings, :price_levels) do
    def self.default
      new(areas: Condition::AREAS, settings: Condition::SETTINGS, price_levels: Condition::PRICE_LABELS)
    end
  end

  def self.current
    klass = Rails.application.config.x.scout_class.presence || "Scouts::Deterministic"
    klass.constantize.new
  end
end
