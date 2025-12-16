class DashboardController < ApplicationController
  def show
    @latest_prompt = current_user.prompts.order(created_at: :desc).first
    @last_sent_prompt = current_user.prompts.where.not(sent_at: nil).order(sent_at: :desc).first
    @recent_entries = current_user.journal_entries.includes(:prompt, :entry_analysis).order(received_at: :desc, created_at: :desc).limit(10)
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

    # If prompt_id is provided, resend that specific prompt
    if params[:prompt_id].present?
      prompt_id = params[:prompt_id].to_i
      prompt = current_user.prompts.find_by(id: prompt_id)

      unless prompt
        redirect_to dashboard_path, alert: "Prompt not found."
        return
      end

      begin
        # Resend existing prompt via mailer
        PromptMailer.prompt_email(prompt.id).deliver_now
        prompt.update_column(:sent_at, Time.current) unless prompt.sent_at.present?

        # Create EmailMessage record
        EmailMessage.create!(
          user: current_user,
          prompt: prompt,
          direction: "outbound",
          subject: "Your journaling prompt",
          body: prompt.body || "#{prompt.question_1}\n\n#{prompt.question_2}",
          sent_or_received_at: Time.current
        )

        redirect_to dashboard_path, notice: "Email sent successfully!"
      rescue StandardError => e
        Rails.logger.error "Failed to send prompt email: #{e.message}"
        redirect_to dashboard_path, alert: "Failed to send email: #{e.message}"
      end
    else
      # Generate and send a new prompt
      begin
        PromptSender.new(current_user).send_prompt!
        redirect_to dashboard_path, notice: "Prompt email sent successfully!"
      rescue StandardError => e
        Rails.logger.error "Failed to send prompt: #{e.message}"
        redirect_to dashboard_path, alert: "Failed to send prompt: #{e.message}"
      end
    end
  end

  def toggle_schedule
    if current_user.schedule_paused?
      current_user.resume_schedule!
      redirect_to dashboard_path, notice: "Schedule resumed. You'll receive prompts at your scheduled times."
    else
      current_user.pause_schedule!
      redirect_to dashboard_path, notice: "Schedule paused. You won't receive automatic prompts until you resume."
    end
  end
end
