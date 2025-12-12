class PromptGenerator
  MAX_CONTEXT_ENTRIES = 8

  def initialize(user)
    @user = user
  end

  def generate!
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

    question =
      if ENV["OPENAI_API_KEY"].present?
        generate_with_openai(context, last_prompt&.body)
      else
        fallback_question(last_prompt&.body)
      end

    Prompt.create!(
      user: @user,
      body: question,
      source: "ai",
      parent_prompt_id: last_prompt&.id
    )
  end

  private

  def generate_with_openai(context, last_prompt_body)
    require "openai"

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    system_prompt = <<~SYS
      You are a warm, curious journaling companion.
      The user writes private journal entries. You see short summaries of their recent entries
      and sometimes the last AI prompt they answered.

      Your job:
      - Ask EXACTLY ONE follow-up question.
      - Make it feel personal and specific to the themes you see.
      - You may gently reference patterns (e.g. stress, excitement, relationships, work, health).
      - Avoid generic questions like "How are you feeling?" or "Tell me more."
      - Use natural, conversational language — like a thoughtful friend.
    SYS

    user_prompt = <<~USER
      Recent journal context:

      #{context}

      #{if last_prompt_body.present?
          "The last question you asked was:\n\"#{last_prompt_body}\"\n\nWrite a NEW follow-up question that builds on where that conversation has been going."
        else
          "The user has not had an AI prompt before. Ask a first question that helps them start reflecting on what has been on their mind recently."
        end}
    USER

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user",   content: user_prompt }
        ],
        temperature: 0.7,
        max_tokens: 120
      }
    )

    response.dig("choices", 0, "message", "content")&.strip ||
      fallback_question(last_prompt_body)
  rescue StandardError => e
    Rails.logger.error "OpenAI prompt error: #{e.message}"
    fallback_question(last_prompt_body)
  end

  def fallback_question(last_prompt_body)
    if last_prompt_body.present?
      "Thinking back to what you wrote in response to that last question, what still feels unresolved or important to you right now?"
    else
      "What has been on your mind the most over the last few days?"
    end
  end
end
