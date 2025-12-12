class PromptSender
  def initialize(user)
    @user = user
  end

  def send_prompt!
    # Generate the prompt
    prompt = PromptGenerator.new(@user).generate!
    
    # Send the email
    PromptMailer.prompt_email(prompt).deliver_now
    
    # Update prompt sent_at
    prompt.update_column(:sent_at, Time.current)
    
    # Log outbound email
    email_body = <<~BODY
      Question 1: #{prompt.question_1}
      
      Question 2: #{prompt.question_2}
      
      Reply to this email to create a journal entry.
    BODY
    
    EmailMessage.create!(
      user: @user,
      direction: "outbound",
      prompt: prompt,
      subject: "Your journaling questions for today",
      body: email_body,
      sent_or_received_at: Time.current
    )
    
    # Update user's next_prompt_at
    @user.update_next_prompt_at!
    
    prompt
  end
end
