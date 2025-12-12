class DashboardController < ApplicationController
  def show
    @latest_prompt = current_user.prompts.order(created_at: :desc).first
    @recent_entries = current_user.journal_entries.includes(:prompt).order(created_at: :desc).limit(10)
  end
end
