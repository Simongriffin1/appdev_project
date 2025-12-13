class PromptMailer < ApplicationMailer
  def prompt_email(prompt_id)
    @prompt = Prompt.find(prompt_id)
    @user = @prompt.user

    token = Rails.application.message_verifier(:journal_reply).generate([@user.id, @prompt.id])
    inbound_domain = ENV.fetch("INBOUND_EMAIL_DOMAIN", "example.com")
    reply_address = "reply+#{token}@#{inbound_domain}"

    mail(
      to: @user.email,
      reply_to: reply_address,
      subject: "Your journal prompts (2 questions)"
    )
  end
end
