class DashboardController < ApplicationController
  def show
    @latest_prompt = current_user.prompts.order(created_at: :desc).first
    @recent_entries = current_user.journal_entries.includes(:prompt).order(received_at: :desc, created_at: :desc).limit(10)
  end

  # Dashboard button: send the next scheduled prompt immediately.
  def send_prompt
    unless current_user.onboarding_complete?
      redirect_to settings_path, alert: "Please complete your settings first."
      return
    end

    PromptSender.new(current_user).send_prompt!
    redirect_to dashboard_path, notice: "Prompt email sent successfully!"
  rescue StandardError => e
    Rails.logger.error "Failed to send prompt: #{e.message}"
    redirect_to dashboard_path, alert: "Failed to send prompt: #{e.message}"
  end

  # Backwards-compatible route (optional).
  def send_next_prompt
    send_prompt
  end
end
