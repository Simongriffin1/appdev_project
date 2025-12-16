class PromptSender
  def initialize(user)
    @user = user
  end

  def send_prompt!
    begin
      prompt = PromptGenerator.new(@user).generate!
    rescue StandardError => e
      # Log error but don't crash - PromptGenerator should always return a prompt (fallback)
      Rails.logger.error "PromptGenerator error for user #{@user.id}: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      
      # If generation completely failed, we can't proceed
      raise e
    end

    # Generate idempotency_key if not set (should be set by PromptGenerator, but ensure it)
    if prompt.idempotency_key.blank?
      timestamp = Time.current
      prompt.update_column(:idempotency_key, Digest::MD5.hexdigest("#{@user.id}-#{timestamp.to_i}"))
    end

    begin
      # Send email
      PromptMailer.prompt_email(prompt.id).deliver_now

      # Update prompt status and sent_at
      prompt.mark_as_sent!
      
      # Update user's last_prompt_sent_at (critical for idempotency)
      if @user.respond_to?(:last_prompt_sent_at)
        @user.update_column(:last_prompt_sent_at, Time.current)
      end

      # Log email message
      EmailMessage.create!(
        user: @user,
        direction: "outbound",
        prompt: prompt,
        subject: prompt.subject || "Your journaling questions for today",
        body: prompt.body || "#{prompt.question_1}\n\n#{prompt.question_2}",
        sent_or_received_at: Time.current
      )

      # Compute and update next_prompt_at based on schedule
      @user.update_next_prompt_at!
      
      Rails.logger.info "Successfully sent prompt #{prompt.id} to user #{@user.id}, next prompt at: #{@user.next_prompt_at}"
    rescue StandardError => e
      # Log email sending errors but don't fail the job
      Rails.logger.error "Failed to send prompt email for user #{@user.id}: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      # Still return the prompt even if email failed
    end

    prompt
  end
end
