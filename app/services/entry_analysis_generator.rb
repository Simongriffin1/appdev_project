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
    # Use a balanced brace matcher to handle nested structures (arrays, objects)
    json_text = extract_json_object(json_text)
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

  def extract_json_object(text)
    # Find the first opening brace
    start_idx = text.index("{")
    return nil unless start_idx

    # Count braces to find the matching closing brace
    brace_count = 0
    in_string = false
    escape_next = false

    (start_idx...text.length).each do |i|
      char = text[i]

      if escape_next
        escape_next = false
        next
      end

      if char == "\\"
        escape_next = true
        next
      end

      if char == '"' && !escape_next
        in_string = !in_string
        next
      end

      next if in_string

      if char == "{"
        brace_count += 1
      elsif char == "}"
        brace_count -= 1
        if brace_count == 0
          return text[start_idx..i]
        end
      end
    end

    # If we didn't find a matching closing brace, return nil
    nil
  end

  def fallback_analysis
    # Deterministic analysis based on keywords and patterns
    body_lower = @entry.body.downcase

    # Detect sentiment from keywords
    positive_words = %w[happy joy excited grateful thankful proud love amazing wonderful great good]
    negative_words = %w[sad angry frustrated anxious worried stressed upset disappointed hurt]

    positive_count = positive_words.count { |word| body_lower.include?(word) }
    negative_count = negative_words.count { |word| body_lower.include?(word) }

    sentiment = if positive_count > negative_count
                  "positive"
                elsif negative_count > positive_count
                  "negative"
                else
                  "neutral"
                end

    # Detect emotion from keywords
    emotion_keywords = {
      "joy" => %w[happy joy excited thrilled delighted],
      "anxiety" => %w[anxious worried nervous stressed tense],
      "frustration" => %w[frustrated annoyed irritated],
      "sadness" => %w[sad depressed down low],
      "anger" => %w[angry mad furious],
      "calm" => %w[calm peaceful relaxed serene],
      "pride" => %w[proud accomplished achieved],
      "gratitude" => %w[grateful thankful appreciate]
    }

    detected_emotion = "neutral"
    emotion_keywords.each do |emotion, keywords|
      if keywords.any? { |word| body_lower.include?(word) }
        detected_emotion = emotion
        break
      end
    end

    # Extract simple topics from common words
    common_topics = {
      "work" => %w[work job office meeting project deadline],
      "relationships" => %w[friend family partner relationship love],
      "health" => %w[health exercise workout gym sick],
      "travel" => %w[travel trip vacation journey],
      "learning" => %w[learn study read book class],
      "creativity" => %w[creative art write draw music],
      "reflection" => %w[think reflect consider ponder]
    }

    detected_topics = []
    common_topics.each do |topic, keywords|
      if keywords.any? { |word| body_lower.include?(word) }
        detected_topics << topic
      end
    end

    # Generate a simple summary
    first_sentence = @entry.body.split(/[.!?]/).first&.strip
    summary = if first_sentence && first_sentence.length > 20
                "#{first_sentence.truncate(150)}."
              else
                @entry.body.truncate(200)
              end

    {
      summary: summary,
      sentiment: sentiment,
      emotion: detected_emotion,
      topics: detected_topics.first(3) # Limit to 3 topics
    }
  end
end
