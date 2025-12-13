class DashboardController < ApplicationController
  def show
    @latest_prompt = current_user.prompts.order(created_at: :desc).first
    @recent_entries = current_user.journal_entries.includes(:prompt).order(received_at: :desc, created_at: :desc).limit(10)
  end

  def send_next_prompt
    authenticate_user!
    PromptSender.new(current_user).send_prompt!
    redirect_to dashboard_path, notice: "Sent you an email with your prompts."
  end


  def send_prompt
    unless current_user.onboarding_complete?
      redirect_to settings_path, alert: "Please complete your settings first."
      return
    end

    begin
      PromptSender.new(current_user).send_prompt!
      redirect_to dashboard_path, notice: "Prompt email sent successfully!"
    rescue StandardError => e
      Rails.logger.error "Failed to send prompt: #{e.message}"
      redirect_to dashboard_path, alert: "Failed to send prompt: #{e.message}"
    end
  end

  def send_prompt
    prompt_id = params[:prompt_id].to_i
    prompt = current_user.prompts.find_by(id: prompt_id)

    unless prompt
      redirect_to dashboard_path, alert: "Prompt not found."
      return
    end

    # Check if SMTP is configured
    unless ENV["SMTP_ADDRESS"].present? && ENV["MAIL_FROM"].present?
      redirect_to dashboard_path, alert: "Email configuration is missing. Please set SMTP_ADDRESS and MAIL_FROM in your .env file."
      return
    end

    begin
      # Send email using the mailer (passing ID, not object)
      PromptMailer.prompt_email(prompt.id).deliver_now

      # Create EmailMessage record
      EmailMessage.create!(
        user: current_user,
        prompt: prompt,
        journal_entry: nil, # No journal entry yet for outbound prompt emails
        direction: "outbound",
        subject: "Your journaling prompt",
        body: prompt.body,
        sent_or_received_at: Time.current
      )

      redirect_to dashboard_path, notice: "Email sent successfully!"
    rescue StandardError => e
      Rails.logger.error "Failed to send prompt email: #{e.message}"
      redirect_to dashboard_path, alert: "Failed to send email: #{e.message}"
    end
  end
end
