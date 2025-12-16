require "json"

class EntryAnalysisGenerator
  MIN_TAGS = 3
  MAX_TAGS = 6

  def initialize(journal_entry)
    @entry = journal_entry
  end

  def generate!
    # Skip if analysis already exists
    return @entry.entry_analysis if @entry.entry_analysis.present?

    # Generate analysis using OpenAI if available, otherwise use fallback
    analysis_data = generate_analysis

    # Create EntryAnalysis
    analysis = EntryAnalysis.create!(
      journal_entry: @entry,
      summary: analysis_data[:summary],
      sentiment: analysis_data[:sentiment],
      emotion: analysis_data[:emotion],
      tags: analysis_data[:tags], # JSON array
      key_themes: analysis_data[:key_themes] # JSON array
    )

    # Create or find topics and link them
    analysis_data[:tags].each do |topic_name|
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

  def generate_analysis
    entry_body = @entry.cleaned_body.presence || @entry.body.to_s
    
    # Check cache first
    cache_key = "entry_analysis:#{@entry.id}:#{Digest::MD5.hexdigest(entry_body)}"
    cached_result = Rails.cache.read(cache_key)
    if cached_result
      Rails.logger.info "Using cached analysis for entry #{@entry.id}"
      return cached_result
    end

    # Try OpenAI if available
    if ENV["OPENAI_API_KEY"].present?
      begin
        # Strip PII from entry body before sending to OpenAI
        sanitized_body = PIIStripper.strip(entry_body)

        client = OpenAIClient.new
        result = client.json_completion(
          system_prompt: build_system_prompt,
          user_prompt: build_user_prompt(sanitized_body),
          model: "gpt-4o-mini",
          temperature: 0.3,
          max_tokens: 400
        )

        # Validate and format response
        tags = Array(result["tags"] || result["topics"] || []).first(MAX_TAGS)
        tags = ensure_min_tags(tags, sanitized_body) if tags.length < MIN_TAGS

        analysis_data = {
          summary: result["summary"]&.strip || fallback_analysis[:summary],
          sentiment: validate_sentiment(result["sentiment"]) || "neutral",
          emotion: result["emotion"]&.strip || "neutral",
          tags: tags,
          key_themes: tags.first(3) # Use first 3 tags as key themes
        }

        # Validate summary length (2-3 sentences)
        analysis_data[:summary] = ensure_summary_length(analysis_data[:summary])

        # Cache successful result
        Rails.cache.write(cache_key, analysis_data, expires_in: 24.hours)
        return analysis_data
      rescue OpenAIClient::Error => e
        # Log error but don't crash - use fallback
        Rails.logger.error "OpenAI error in EntryAnalysisGenerator: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      rescue StandardError => e
        # Catch any other errors
        Rails.logger.error "Unexpected error in EntryAnalysisGenerator: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      end
    end

    # Fallback to non-AI analysis
    fallback_analysis
  end

  def build_system_prompt
    <<~SYS
      You are a helpful assistant that analyzes journal entries.
      Your analysis helps users understand patterns in their reflections.

      Return JSON with these keys:
      - summary: A 2-3 sentence summary of the entry (no personal identifiers)
      - sentiment: One of "positive", "neutral", or "negative"
      - emotion: One main emotion word (e.g., "joy", "anxiety", "frustration", "pride", "sadness", "anger", "calm", "excitement")
      - tags: An array of 3-6 short topic labels (single words or short phrases, no personal info)

      Important:
      - NEVER include email addresses, names, or other personal identifiers in your response
      - Summary should be 2-3 sentences, not more
      - Tags should be 3-6 items, descriptive but general
      - Return ONLY valid JSON, no other text
    SYS
  end

  def build_user_prompt(sanitized_body)
    <<~USER
      Here is a journaling entry (PII has been removed):

      #{sanitized_body}

      Please analyze this entry and return the JSON as specified.
    USER
  end

  def validate_sentiment(sentiment)
    valid_sentiments = %w[positive neutral negative]
    valid_sentiments.include?(sentiment&.downcase) ? sentiment.downcase : nil
  end

  def ensure_min_tags(tags, body)
    # If we have fewer than MIN_TAGS, try to extract more from the body
    common_topics = {
      "work" => %w[work job office meeting project deadline career],
      "relationships" => %w[friend family partner relationship love social],
      "health" => %w[health exercise workout gym sick wellness],
      "travel" => %w[travel trip vacation journey adventure],
      "learning" => %w[learn study read book class education],
      "creativity" => %w[creative art write draw music expression],
      "reflection" => %w[think reflect consider ponder contemplate],
      "emotions" => %w[feel feeling emotion mood],
      "goals" => %w[goal plan achieve accomplish target]
    }

    body_lower = body.downcase
    common_topics.each do |topic, keywords|
      if keywords.any? { |word| body_lower.include?(word) } && !tags.include?(topic)
        tags << topic
        break if tags.length >= MIN_TAGS
      end
    end

    # Fill remaining slots with generic tags if needed
    while tags.length < MIN_TAGS
      generic_tags = ["reflection", "thoughts", "experience", "insight"]
      tag = generic_tags.find { |t| !tags.include?(t) }
      tags << tag if tag
      break if tags.length >= MIN_TAGS || !tag
    end

    tags.first(MAX_TAGS)
  end

  def ensure_summary_length(summary)
    sentences = summary.split(/[.!?]+/).reject(&:blank?)
    
    if sentences.length > 3
      # Take first 3 sentences
      sentences.first(3).join(". ") + "."
    elsif sentences.length < 2
      # Ensure at least 2 sentences
      if sentences.any?
        first_sentence = sentences.first
        # Split long sentence or add a generic second sentence
        if first_sentence.length > 100
          parts = first_sentence.split(/[,;]/)
          if parts.length >= 2
            "#{parts.first.strip}.#{parts[1..-1].join(', ')}."
          else
            "#{first_sentence.strip}. This entry reflects on personal experiences."
          end
        else
          "#{first_sentence.strip}. This entry reflects on personal experiences."
        end
      else
        "This entry contains personal reflections. The user is processing their thoughts and experiences."
      end
    else
      summary
    end
  end

  def fallback_analysis
    # Deterministic analysis based on keywords and patterns
    entry_body = @entry.cleaned_body.presence || @entry.body.to_s
    body_lower = entry_body.downcase

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

    # Extract topics from common words
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

    # Ensure we have 3-6 tags
    detected_topics = ensure_min_tags(detected_topics, entry_body)

    # Generate a simple summary (2-3 sentences)
    sentences = entry_body.split(/[.!?]/).reject(&:blank?).first(3)
    summary = if sentences.length >= 2
                sentences.first(3).join(". ") + "."
              else
                first_sentence = sentences.first || entry_body.truncate(100)
                "#{first_sentence.strip}. This entry reflects on personal experiences."
              end

    {
      summary: summary,
      sentiment: sentiment,
      emotion: detected_emotion,
      tags: detected_topics.first(MAX_TAGS),
      key_themes: detected_topics.first(3)
    }
  end
end
