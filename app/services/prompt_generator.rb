class PromptGenerator
  MAX_CONTEXT_ENTRIES = 5

  def initialize(user)
    @user = user
  end

  def generate!
    # Get last 5 journal entries for context
    recent_entries = @user.journal_entries
                          .includes(:entry_analysis)
                          .order(created_at: :desc)
                          .limit(MAX_CONTEXT_ENTRIES)

    # Build a human-readable context summary
    context_blocks = recent_entries.map do |entry|
      label = entry.created_at.strftime("%b %-d")
      summary = if entry.entry_analysis&.summary.present?
                  entry.entry_analysis.summary
                else
                  entry.body.truncate(200)
                end

      topics = entry.entry_analysis&.keywords.to_s
      topics_text = topics.present? ? "Topics: #{topics}" : nil

      [ "#{label}: #{summary}", topics_text ].compact.join("\n")
    end

    context = if context_blocks.any?
                context_blocks.reverse.join("\n\n")
              else
                "No prior entries. The user is just starting their journaling habit."
              end

    last_prompt = @user.prompts.order(created_at: :desc).first

    questions =
      if ENV["OPENAI_API_KEY"].present?
        generate_with_openai(context, last_prompt)
      else
        fallback_questions(last_prompt)
      end

    Prompt.create!(
      user: @user,
      question_1: questions[:question_1],
      question_2: questions[:question_2],
      body: "#{questions[:question_1]}\n\n#{questions[:question_2]}", # Keep body for backward compatibility
      source: "ai",
      parent_prompt_id: last_prompt&.id
    )
  end

  private

  def generate_with_openai(context, last_prompt)
    require "openai"
    require "json"

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    system_prompt = <<~SYS
      You are a warm, curious journaling companion.
      The user writes private journal entries. You see short summaries of their recent entries
      and sometimes the last AI prompt they answered.

      Your job:
      - Generate EXACTLY TWO follow-up questions as JSON with keys: question_1, question_2
      - Make them feel personal and specific to the themes you see in their recent entries
      - You may gently reference patterns (e.g. stress, excitement, relationships, work, health)
      - Avoid generic questions like "How are you feeling?" or "Tell me more."
      - Use natural, conversational language — like a thoughtful friend
      - The two questions should complement each other but be distinct
      - Return ONLY valid JSON, no other text
    SYS

    last_prompt_text = if last_prompt && last_prompt.question_1.present? && last_prompt.question_2.present?
                         "The last questions you asked were:\n\"#{last_prompt.question_1}\"\n\"#{last_prompt.question_2}\"\n\nWrite NEW follow-up questions that build on where that conversation has been going."
                       elsif last_prompt && last_prompt.body.present?
                         "The last question you asked was:\n\"#{last_prompt.body}\"\n\nWrite NEW follow-up questions that build on where that conversation has been going."
                       else
                         "The user has not had an AI prompt before. Ask two first questions that help them start reflecting on what has been on their mind recently."
                       end

    user_prompt = <<~USER
      Recent journal context:

      #{context}

      #{last_prompt_text}
    USER

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user",   content: user_prompt }
        ],
        temperature: 0.7,
        max_tokens: 300,
        response_format: { type: "json_object" }
      }
    )

    json_text = response.dig("choices", 0, "message", "content")&.strip
    return fallback_questions(last_prompt) if json_text.blank?

    # Try to extract JSON from the response (in case there's extra text)
    json_match = json_text.match(/\{.*?\}/m)
    json_text = json_match[0] if json_match
    return fallback_questions(last_prompt) if json_text.blank?

    parsed = JSON.parse(json_text)
    {
      question_1: parsed["question_1"] || fallback_questions(last_prompt)[:question_1],
      question_2: parsed["question_2"] || fallback_questions(last_prompt)[:question_2]
    }
  rescue StandardError => e
    Rails.logger.error "OpenAI prompt error: #{e.message}"
    fallback_questions(last_prompt)
  end

  def fallback_questions(last_prompt)
    if last_prompt&.question_1.present?
      {
        question_1: "Thinking back to what you wrote in response to that last question, what still feels unresolved or important to you right now?",
        question_2: "What patterns or themes are you noticing in your recent reflections?"
      }
    else
      {
        question_1: "What has been on your mind the most over the last few days?",
        question_2: "What moment from this week stands out to you, and why?"
      }
    end
  end
end
