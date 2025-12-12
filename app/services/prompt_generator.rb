class PromptGenerator
  def initialize(user)
    @user = user
  end

  def generate!
    # Fetch recent entries with their analyses
    recent_entries = @user.journal_entries
      .order(created_at: :desc)
      .includes(:entry_analysis)
      .limit(10)

    # Build context string from recent entries
    context_parts = recent_entries.map do |entry|
      if entry.entry_analysis&.summary.present?
        entry.entry_analysis.summary
      else
        entry.body.truncate(200)
      end
    end

    context = context_parts.join("\n\n")

    # Generate prompt using OpenAI if available, otherwise use fallback
    question = if ENV["OPENAI_API_KEY"].present?
                 generate_with_openai(context)
               else
                 fallback_question
               end

    # Get the most recent prompt to use as parent
    parent_prompt = @user.prompts.order(created_at: :desc).first

    # Create and return the new prompt
    Prompt.create!(
      user: @user,
      body: question,
      source: "ai",
      parent_prompt_id: parent_prompt&.id
    )
  end

  private

  def generate_with_openai(context)
    require "openai"

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    system_prompt = "You are a journaling coach. Based on the recent reflections below, respond with ONLY ONE short, thoughtful follow-up question to help the user reflect further."

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: context.presence || "This is a new journaling user with no previous entries." }
        ],
        temperature: 0.7,
        max_tokens: 150
      }
    )

    response.dig("choices", 0, "message", "content")&.strip || fallback_question
  rescue StandardError => e
    Rails.logger.error "OpenAI API error: #{e.message}"
    fallback_question
  end

  def fallback_question
    "What stood out to you about today?"
  end
end
