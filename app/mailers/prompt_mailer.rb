class PromptMailer < ApplicationMailer
  def prompt_email(prompt)
    @prompt = prompt
    @user = prompt.user
    
    # Generate a signed token for reply-to address
    token = generate_reply_token(@user.id, prompt.id)
    reply_to_address = "reply+#{token}@#{default_from_domain}"
    
    mail(
      to: @user.email,
      reply_to: reply_to_address,
      subject: "Your journaling questions for today"
    )
  end

  private

  def generate_reply_token(user_id, prompt_id)
    # Use Rails message verifier to create a signed token
    verifier = Rails.application.message_verifier(:journal_reply)
    verifier.generate([user_id, prompt_id])
  end

  def default_from_domain
    # In production, this should be your actual domain
    # For local development, use a placeholder
    ENV.fetch("MAIL_DOMAIN", "localhost")
  end
end
