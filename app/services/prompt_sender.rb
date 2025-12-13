class PromptSender
  def initialize(user)
    @user = user
  end

  def send_prompt!
    prompt = PromptGenerator.new(@user).generate!

    # FIX: pass ID, not object
    PromptMailer.prompt_email(prompt.id).deliver_now

    prompt.update_column(:sent_at, Time.current)

    EmailMessage.create!(
      user: @user,
      direction: "outbound",
      prompt: prompt,
      subject: "Your journaling questions for today",
      body: "#{prompt.question_1}\n\n#{prompt.question_2}",
      sent_or_received_at: Time.current
    )

    @user.update_next_prompt_at!

    prompt
  end
end
