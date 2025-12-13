class JournalReplyMailbox < ApplicationMailbox
  # Called when ApplicationMailbox routes an email to :journal_reply
  def process
    token = extract_token
    return bounce_with("Invalid reply token") unless token

    user_id, prompt_id = verify_token(token)
    return bounce_with("Invalid or expired token") unless user_id && prompt_id

    user = User.find_by(id: user_id)
    return bounce_with("User not found") unless user

    prompt = Prompt.find_by(id: prompt_id, user_id: user_id)
    return bounce_with("Prompt not found") unless prompt

    body = extract_body
    return bounce_with("Empty reply") if body.blank?

    journal_entry = JournalEntry.create!(
      user: user,
      prompt: prompt,
      body: body.strip,
      source: "email",
      received_at: mail.date || Time.current
    )

    EmailMessage.create!(
      user: user,
      direction: "inbound",
      prompt: prompt,
      journal_entry: journal_entry,
      subject: mail.subject,
      body: body,
      sent_or_received_at: mail.date || Time.current
    )

    EntryAnalysisGenerator.new(journal_entry).generate!
  end

  private

  def extract_token
    # Prefer Reply-To (how many clients respond), else fall back to To
    address = mail.reply_to&.first || mail.to&.first
    return nil unless address

    match = address.match(/^reply\+([^@]+)@/i)
    match ? match[1] : nil
  end

  def extract_body
    # Prefer plain text. Fallback to HTML then raw body.
    mail.text_part&.decoded || mail.html_part&.decoded || mail.body&.decoded
  end

  def verify_token(token)
    Rails.application.message_verifier(:journal_reply).verify(token)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    [nil, nil]
  end
end
