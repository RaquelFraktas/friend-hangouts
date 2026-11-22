class HomeController < ApplicationController
  # Local-demo convenience: lists dashboards in development only. In any other
  # environment the organizer must already have their private link.
  def index
    @hangouts = Rails.env.development? ? Hangout.order(:id).to_a : []
  end
end
