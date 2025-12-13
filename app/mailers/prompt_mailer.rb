class PromptMailer < ApplicationMailer
  def prompt_email(prompt_id)
    @prompt = Prompt.find(prompt_id)
    @user = @prompt.user

    token = Rails.application.message_verifier(:journal_reply).generate([@user.id, @prompt.id])
    # In development you typically want this to be "localhost" so ActionMailbox Conductor
    # can deliver messages to reply+TOKEN@localhost.
    inbound_domain = ENV.fetch("MAIL_DOMAIN", "localhost")
    reply_address = "reply+#{token}@#{inbound_domain}"

    mail(
      to: @user.email,
      reply_to: reply_address,
      subject: "Your journal prompts (2 questions)"
    )
  end
end
