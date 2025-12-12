class PromptMailer < ApplicationMailer
  def prompt_email(prompt_id)
    @prompt = Prompt.find(prompt_id)
    @user = @prompt.user

    mail(
      to: @user.email,
      subject: "Your journal prompts (2 questions)"
    )
  end
end
