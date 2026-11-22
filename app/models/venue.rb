class Venue < ApplicationRecord
  validates :name, :area, presence: true
  validates :area, inclusion: { in: Condition::AREAS }
  validates :setting, inclusion: { in: Condition::SETTINGS }
  validates :price_level, inclusion: { in: 1..3 }

  def price_label = Condition::PRICE_LABELS[price_level]

  def summary
    [ neighborhood.presence ? "#{neighborhood}, #{area}" : area, price_label, setting,
      (accessible ? "step-free" : nil) ].compact.join(" · ")
  end
end
