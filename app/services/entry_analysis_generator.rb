require "json"

class EntryAnalysisGenerator
  def initialize(journal_entry)
    @entry = journal_entry
  end

  def generate!
    # Skip if analysis already exists (or update it - for now we'll skip)
    return @entry.entry_analysis if @entry.entry_analysis.present?

    # Generate analysis using OpenAI if available, otherwise use fallback
    analysis_data = if ENV["OPENAI_API_KEY"].present?
                      generate_with_openai
                    else
                      fallback_analysis
                    end

    # Create EntryAnalysis
    analysis = EntryAnalysis.create!(
      journal_entry: @entry,
      summary: analysis_data[:summary],
      sentiment: analysis_data[:sentiment],
      emotion: analysis_data[:emotion],
      keywords: analysis_data[:topics].join(", ")
    )

    # Create or find topics and link them
    analysis_data[:topics].each do |topic_name|
      next if topic_name.blank?

      normalized_name = topic_name.strip.downcase
      next if normalized_name.blank?

      topic = @entry.user.topics.find_or_create_by!(name: normalized_name)
      EntryTopic.find_or_create_by!(
        journal_entry: @entry,
        topic: topic
      )
    end

    analysis
  end

  private

  def generate_with_openai
    require "openai"

    client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

    prompt = <<~PROMPT
      Here is a journaling entry:

      #{@entry.body}

      Please analyze this entry and return JSON with the following keys:
      - summary: A 1-3 sentence summary of the entry
      - sentiment: One of "positive", "neutral", or "negative"
      - emotion: One main emotion word (e.g., "joy", "anxiety", "frustration", "pride", "sadness", "anger", "calm", "excitement")
      - topics: An array of 1-3 short topic labels (single words or short phrases)

      Return ONLY valid JSON, no other text.
    PROMPT

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: "You are a helpful assistant that analyzes journal entries. Always return valid JSON." },
          { role: "user", content: prompt }
        ],
        temperature: 0.3,
        max_tokens: 300,
        response_format: { type: "json_object" }
      }
    )

    json_text = response.dig("choices", 0, "message", "content")&.strip
    return fallback_analysis if json_text.blank?

    # Try to extract JSON from the response (in case there's extra text)
    json_match = json_text.match(/\{.*?\}/m)
    json_text = json_match[0] if json_match
    return fallback_analysis if json_text.blank?

    parsed = JSON.parse(json_text)

    {
      summary: parsed["summary"] || fallback_analysis[:summary],
      sentiment: parsed["sentiment"] || "neutral",
      emotion: parsed["emotion"] || "neutral",
      topics: Array(parsed["topics"] || [])
    }
  rescue StandardError => e
    Rails.logger.error "OpenAI API error: #{e.message}"
    fallback_analysis
  end

  def fallback_analysis
    {
      summary: @entry.body.truncate(200),
      sentiment: "neutral",
      emotion: "neutral",
      topics: []
    }
  end
end
