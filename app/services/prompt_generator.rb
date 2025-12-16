class PromptGenerator
  MAX_CONTEXT_DAYS = 7
  MAX_WORDS_TOTAL = 60

  def initialize(user)
    @user = user
  end

  def generate!
    # Get recent entries from last 7 days
    recent_entries = @user.journal_entries
                          .includes(:entry_analysis)
                          .where("received_at >= ? OR created_at >= ?", MAX_CONTEXT_DAYS.days.ago, MAX_CONTEXT_DAYS.days.ago)
                          .order(received_at: :desc, created_at: :desc)
                          .limit(10)

    # Build context summary (strip PII)
    context = build_context(recent_entries)

    last_prompt = @user.prompts.order(created_at: :desc).first

    # Generate questions with OpenAI or fallback
    questions_result = generate_questions(context, last_prompt, recent_entries)

    # Ensure total word count is <= 60
    questions_result = enforce_word_limit(questions_result)

    # Generate idempotency key for scheduled window
    idempotency_key = generate_idempotency_key

    # Create prompt record (draft status)
    Prompt.create!(
      user: @user,
      question_1: questions_result[:question_1],
      question_2: questions_result[:question_2],
      body: "#{questions_result[:question_1]}\n\n#{questions_result[:question_2]}",
      subject: questions_result[:subject] || "Your journal prompts (2 questions)",
      source: "ai",
      prompt_type: :daily,
      parent_prompt_id: last_prompt&.id,
      status: :draft,
      idempotency_key: idempotency_key
    )
  end

  private

  def build_context(recent_entries)
    return "No prior entries. The user is just starting their journaling habit." if recent_entries.empty?

    context_blocks = recent_entries.map do |entry|
      label = (entry.received_at || entry.created_at).strftime("%b %-d")
      
      # Use analysis summary if available, otherwise use cleaned body (strip PII)
      summary = if entry.entry_analysis&.summary.present?
                  PIIStripper.strip(entry.entry_analysis.summary)
                else
                  entry_body = entry.cleaned_body.presence || entry.body.to_s
                  PIIStripper.strip(entry_body.truncate(200))
                end

      # Use tags (array) or fallback to keywords (string) for backward compatibility
      topics = if entry.entry_analysis&.tags.present?
                 entry.entry_analysis.tags.join(", ")
               else
                 entry.entry_analysis&.keywords.to_s
               end
      topics_text = topics.present? ? "Topics: #{topics}" : nil

      [ "#{label}: #{summary}", topics_text ].compact.join("\n")
    end

    context_blocks.reverse.join("\n\n")
  end

  def generate_questions(context, last_prompt, recent_entries)
    # Check cache first
    cache_key = "prompt_generator:#{@user.id}:#{Digest::MD5.hexdigest(context)}"
    cached_result = Rails.cache.read(cache_key)
    if cached_result
      Rails.logger.info "Using cached prompt for user #{@user.id}"
      return cached_result
    end

    # Try OpenAI if available
    if ENV["OPENAI_API_KEY"].present?
      begin
        client = OpenAIClient.new
        result = client.json_completion(
          system_prompt: build_system_prompt,
          user_prompt: build_user_prompt(context, last_prompt),
          model: "gpt-4o-mini",
          temperature: 0.7,
          max_tokens: 200 # Reduced for shorter responses
        )

        # Validate and format response
        questions = {
          question_1: result["question_1"]&.strip,
          question_2: result["question_2"]&.strip,
          subject: result["subject"]&.strip
        }

        # Validate questions exist
        if questions[:question_1].present? && questions[:question_2].present?
          # Cache successful result
          Rails.cache.write(cache_key, questions, expires_in: 1.hour)
          return questions
        else
          Rails.logger.warn "OpenAI returned incomplete questions, using fallback"
        end
      rescue OpenAIClient::Error => e
        # Log error but don't crash - use fallback
        Rails.logger.error "OpenAI error in PromptGenerator: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      rescue StandardError => e
        # Catch any other errors
        Rails.logger.error "Unexpected error in PromptGenerator: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      end
    end

    # Fallback to non-AI prompts
    fallback_questions(last_prompt, recent_entries)
  end

  def build_system_prompt
    tone_preference = @user.respond_to?(:tone_preference) ? @user.tone_preference : nil
    tone_instruction = case tone_preference
                      when "casual"
                        "Use a casual, friendly tone."
                      when "formal"
                        "Use a more formal, professional tone."
                      when "warm"
                        "Use a warm, empathetic tone."
                      else
                        "Use a warm, conversational tone."
                      end

    <<~SYS
      You are a warm, curious journaling companion.
      The user writes private journal entries. You see short summaries of their recent entries.

      Your job:
      - Generate EXACTLY TWO short questions as JSON with keys: question_1, question_2, subject
      - Total word count for BOTH questions combined must be <= 60 words
      - Make them feel personal and specific to the themes you see in their recent entries
      - You may gently reference patterns (e.g. stress, excitement, relationships, work, health)
      - Avoid generic questions like "How are you feeling?" or "Tell me more."
      - #{tone_instruction}
      - The two questions should complement each other but be distinct
      - Subject should be a short, friendly subject line (max 10 words)
      - Return ONLY valid JSON, no other text
      - NEVER echo or reference the user's email address or any personal identifiers
    SYS
  end

  def build_user_prompt(context, last_prompt)
    last_prompt_text = if last_prompt && last_prompt.question_1.present? && last_prompt.question_2.present?
                         # Strip PII from last prompt
                         last_q1 = PIIStripper.strip(last_prompt.question_1)
                         last_q2 = PIIStripper.strip(last_prompt.question_2)
                         "The last questions you asked were:\n\"#{last_q1}\"\n\"#{last_q2}\"\n\nWrite NEW follow-up questions that build on where that conversation has been going."
                       elsif last_prompt && last_prompt.body.present?
                         last_body = PIIStripper.strip(last_prompt.body)
                         "The last question you asked was:\n\"#{last_body}\"\n\nWrite NEW follow-up questions that build on where that conversation has been going."
                       else
                         "The user has not had an AI prompt before. Ask two first questions that help them start reflecting on what has been on their mind recently."
                       end

    <<~USER
      Recent journal context (last 7 days):

      #{context}

      #{last_prompt_text}
    USER
  end

  def enforce_word_limit(questions)
    q1_words = questions[:question_1].to_s.split(/\s+/).length
    q2_words = questions[:question_2].to_s.split(/\s+/).length
    total_words = q1_words + q2_words

    if total_words > MAX_WORDS_TOTAL
      # Proportionally reduce both questions
      ratio = MAX_WORDS_TOTAL.to_f / total_words
      new_q1_words = (q1_words * ratio).floor
      new_q2_words = (q2_words * ratio).floor

      # Truncate questions (rough approximation)
      q1_words_arr = questions[:question_1].to_s.split(/\s+/)
      q2_words_arr = questions[:question_2].to_s.split(/\s+/)

      questions[:question_1] = q1_words_arr.first(new_q1_words).join(" ")
      questions[:question_2] = q2_words_arr.first(new_q2_words).join(" ")
    end

    questions
  end

  def generate_idempotency_key
    # Generate based on user_id and scheduled window (next_prompt_at rounded to hour)
    scheduled_time = @user.next_prompt_at || Time.current
    window_key = scheduled_time.beginning_of_hour.to_i
    
    Digest::MD5.hexdigest("#{@user.id}-#{window_key}")
  end

  def fallback_questions(last_prompt, recent_entries)
    # Non-AI fallback prompts
    if recent_entries.any?
      # Use topics from recent entries if available
      topics = recent_entries.flat_map do |e|
        if e.entry_analysis&.tags.present?
          e.entry_analysis.tags
        elsif e.entry_analysis&.keywords.present?
          e.entry_analysis.keywords.split(", ")
        else
          []
        end
      end.compact.uniq.first(2)

      if topics.any?
        {
          question_1: "What's been most significant about #{topics[0]} for you lately?",
          question_2: "How has #{topics[1] || topics[0]} influenced your thoughts recently?",
          subject: "Your journal prompts"
        }
      else
        {
          question_1: "What pattern do you notice in your recent reflections?",
          question_2: "What would you like to explore deeper?",
          subject: "Your journal prompts"
        }
      end
    elsif last_prompt&.question_1.present?
      {
        question_1: "What still feels important from your last entry?",
        question_2: "What patterns are you noticing?",
        subject: "Your journal prompts"
      }
    else
      {
        question_1: "What has been on your mind the most this week?",
        question_2: "What moment stands out to you, and why?",
        subject: "Your journal prompts"
      }
    end
  end
end
