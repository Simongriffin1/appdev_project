class FollowUpQuestionGenerator
  MAX_FOLLOW_UPS_PER_ENTRY = 1
  MIN_WORD_COUNT = 10 # Consider replies shorter than this as "short"

  def initialize(journal_entry)
    @entry = journal_entry
    @user = journal_entry.user
  end

  def should_send_follow_up?
    return false if @entry.entry_analysis.blank?
    return false if follow_up_already_sent?
    return false if word_count >= MIN_WORD_COUNT && !is_ambiguous?

    true
  end

  def generate_and_send!
    return nil unless should_send_follow_up?

    # Generate follow-up question using OpenAI
    question = if ENV["OPENAI_API_KEY"].present?
                 generate_with_openai
               else
                 fallback_question
               end

    return nil if question.blank?

    # Create prompt as a follow-up (child of the original prompt)
    follow_up_prompt = Prompt.create!(
      user: @user,
      question_1: question,
      question_2: nil,
      body: question,
      subject: "A follow-up question",
      source: "ai_followup",
      prompt_type: :adhoc, # Follow-ups are adhoc
      parent_prompt_id: @entry.prompt_id,
      status: :draft # Will be updated to :sent when email is sent
    )

    # Send email (token generation is handled by PromptMailer)
    PromptMailer.follow_up_email(follow_up_prompt.id, @entry.id).deliver_now

    # Update status and timestamps
    follow_up_prompt.mark_as_sent!
    follow_up_prompt.update_column(:follow_up_sent_at, Time.current)

    # Log email
    EmailMessage.create!(
      user: @user,
      direction: "outbound",
      prompt: follow_up_prompt,
      journal_entry: @entry,
      subject: "A follow-up question",
      body: question,
      sent_or_received_at: Time.current
    )

    follow_up_prompt
  end

  private

  def follow_up_already_sent?
    return false unless @entry.prompt_id

    # Check if a follow-up was already sent for this entry
    Prompt.where(parent_prompt_id: @entry.prompt_id)
          .where.not(sent_at: nil)
          .exists?
  end

  def word_count
    @entry.body.to_s.split(/\s+/).length
  end

  def is_ambiguous?
    # Check if the entry analysis suggests ambiguity
    # Short entries or entries with neutral sentiment might be ambiguous
    return true if word_count < MIN_WORD_COUNT
    return true if @entry.entry_analysis.sentiment == "neutral" && word_count < 30

    # Check if summary is very generic
    summary = @entry.entry_analysis.summary.to_s.downcase
    generic_phrases = ["brief", "short", "not much", "nothing", "same", "okay", "fine"]
    generic_phrases.any? { |phrase| summary.include?(phrase) }
  end

  def generate_with_openai
    # Create a cache key based on entry and analysis
    # Cache for 1 hour to avoid duplicate follow-ups
    entry_body = @entry.cleaned_body.presence || @entry.body.to_s
    cache_key = "follow_up_question:#{@entry.id}:#{Digest::MD5.hexdigest(entry_body)}"
    
    cached_result = Rails.cache.read(cache_key)
    if cached_result
      Rails.logger.info "Using cached follow-up question for entry #{@entry.id}"
      return cached_result
    end

    begin
      # Strip PII from entry body and analysis
      sanitized_body = PIIStripper.strip(entry_body)
      sanitized_summary = @entry.entry_analysis ? PIIStripper.strip(@entry.entry_analysis.summary.to_s) : "No analysis available"
      sanitized_prompt = @entry.prompt ? PIIStripper.strip(@entry.prompt.question_1.to_s || @entry.prompt.body.to_s) : "N/A"

      client = OpenAIClient.new

      system_prompt = <<~SYS
        You are a warm, curious journaling companion.
        The user just replied to a journaling prompt. Their reply was short or ambiguous.
        Generate ONE thoughtful follow-up question that:
        - Encourages deeper reflection
        - Is specific to what they wrote (even if brief)
        - Feels natural and conversational
        - Avoids generic questions like "Tell me more" or "Can you elaborate?"
        - NEVER echo or reference email addresses or personal identifiers
        
        Return ONLY the question text, no JSON, no quotes, just the question.
      SYS

      user_prompt = <<~USER
        Original prompt: #{sanitized_prompt}
        
        User's reply: #{sanitized_body}
        
        Analysis: #{sanitized_summary}
        Sentiment: #{@entry.entry_analysis&.sentiment || "neutral"}
        
        Generate one thoughtful follow-up question.
      USER

      question = client.chat_completion(
        system_prompt: system_prompt,
        user_prompt: user_prompt,
        model: "gpt-4o-mini",
        temperature: 0.7,
        max_tokens: 100,
        json_mode: false
      )

      result = if question.blank?
                 fallback_question
               else
                 # Clean up the question (remove quotes if present)
                 question.gsub(/^["']|["']$/, "").strip
               end

      # Cache the result for 1 hour
      Rails.cache.write(cache_key, result, expires_in: 1.hour)
      result
    rescue OpenAIClient::Error => e
      # Log error but don't crash - use fallback
      Rails.logger.error "OpenAI follow-up question error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      fallback_question
    rescue StandardError => e
      # Catch any other errors
      Rails.logger.error "Unexpected error in follow-up question generation: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      fallback_question
    end
  end

  def fallback_question
    # Generate a contextual fallback based on the entry
    # Use tags (array) or fallback to keywords (string) for backward compatibility
    topics = if @entry.entry_analysis&.tags.present?
               @entry.entry_analysis.tags.first(2)
             elsif @entry.entry_analysis&.keywords.present?
               @entry.entry_analysis.keywords.split(",").first(2).map(&:strip)
             else
               []
             end
    
    if topics.any?
      "What else comes to mind when you think about #{topics.first}?"
    elsif @entry.prompt&.question_1.present?
      "What else would you like to explore about that?"
    else
      "What's one thing you'd like to reflect on a bit more?"
    end
  end
end
