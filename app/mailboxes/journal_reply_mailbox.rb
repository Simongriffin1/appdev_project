class JournalReplyMailbox < ApplicationMailbox
  # Match emails sent to reply+token@domain
  routing(/^reply\+([^@]+)@/i => :journal_reply)

  def journal_reply
    # Extract token from the routing match (from To or Reply-To)
    token = extract_token
    
    return bounce_with("Invalid reply token") unless token
    
    # Verify and decode the token
    user_id, prompt_id = verify_token(token)
    return bounce_with("Invalid or expired token") unless user_id && prompt_id
    
    user = User.find_by(id: user_id)
    return bounce_with("User not found") unless user
    
    prompt = Prompt.find_by(id: prompt_id, user_id: user_id)
    return bounce_with("Prompt not found") unless prompt
    
    # Extract the email body (prefer plain text, fallback to HTML)
    body = mail.text_part&.decoded || mail.html_part&.decoded || mail.body.decoded
    
    # Create journal entry
    journal_entry = JournalEntry.create!(
      user: user,
      prompt: prompt,
      body: body.strip,
      source: "email",
      received_at: mail.date || Time.current
    )
    
    # Log inbound email
    EmailMessage.create!(
      user: user,
      direction: "inbound",
      prompt: prompt,
      journal_entry: journal_entry,
      subject: mail.subject,
      body: body,
      sent_or_received_at: mail.date || Time.current
    )
    
    # Trigger entry analysis generation
    EntryAnalysisGenerator.new(journal_entry).generate!
  end

  private

  def extract_token
    # Try Reply-To first, then To
    address = mail.reply_to&.first || mail.to&.first
    return nil unless address
    
    match = address.match(/^reply\+([^@]+)@/i)
    match ? match[1] : nil
  end

  def verify_token(token)
    verifier = Rails.application.message_verifier(:journal_reply)
    verifier.verify(token)
  rescue
    ActiveSupport::MessageVerifier::InvalidSignature
  [nil, nil]
end
end
