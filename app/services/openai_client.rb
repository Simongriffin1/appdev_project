require "openai"
require "json"

class OpenAIClient
  MAX_RETRIES = 3
  TIMEOUT_SECONDS = 30
  BASE_DELAY = 1 # seconds

  class Error < StandardError; end
  class TimeoutError < Error; end
  class APIError < Error; end
  class InvalidResponseError < Error; end

  def initialize
    @api_key = ENV["OPENAI_API_KEY"]
    raise Error, "OPENAI_API_KEY not configured" unless @api_key.present?

    @client = OpenAI::Client.new(access_token: @api_key, request_timeout: TIMEOUT_SECONDS)
  end

  # Main method for chat completions
  # Options:
  #   - model: model name (default: "gpt-4o-mini")
  #   - temperature: 0.0-2.0 (default: 0.7)
  #   - max_tokens: max response tokens (default: 300)
  #   - json_mode: if true, requests structured JSON response
  #   - system_prompt: system message content
  #   - user_prompt: user message content
  #   - retries: number of retries (default: MAX_RETRIES)
  def chat_completion(system_prompt:, user_prompt:, model: "gpt-4o-mini", temperature: 0.7, max_tokens: 300, json_mode: false, retries: MAX_RETRIES)
    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt }
    ]

    parameters = {
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens
    }

    # Add JSON mode if requested
    if json_mode
      parameters[:response_format] = { type: "json_object" }
    end

    attempt = 0
    begin
      attempt += 1
      response = @client.chat(parameters: parameters)
      
      # Extract content from response
      content = response.dig("choices", 0, "message", "content")&.strip
      
      if content.blank?
        raise InvalidResponseError, "Empty response from OpenAI"
      end

      # If JSON mode, parse and return
      if json_mode
        parsed = parse_json_response(content)
        return parsed
      end

      content
    rescue Faraday::TimeoutError, Timeout::Error => e
      if attempt <= retries
        delay = BASE_DELAY * (2 ** (attempt - 1)) # Exponential backoff
        Rails.logger.warn "OpenAI timeout (attempt #{attempt}/#{retries}), retrying in #{delay}s: #{e.message}"
        sleep delay
        retry
      else
        raise TimeoutError, "OpenAI request timed out after #{retries} attempts: #{e.message}"
      end
    rescue OpenAI::Error => e
      # Handle rate limits and API errors
      if e.message.include?("rate_limit") && attempt <= retries
        delay = BASE_DELAY * (2 ** (attempt - 1))
        Rails.logger.warn "OpenAI rate limit (attempt #{attempt}/#{retries}), retrying in #{delay}s"
        sleep delay
        retry
      elsif attempt <= retries && e.message.include?("server_error")
        delay = BASE_DELAY * (2 ** (attempt - 1))
        Rails.logger.warn "OpenAI server error (attempt #{attempt}/#{retries}), retrying in #{delay}s"
        sleep delay
        retry
      else
        raise APIError, "OpenAI API error: #{e.message}"
      end
    rescue JSON::ParserError => e
      raise InvalidResponseError, "Failed to parse JSON response: #{e.message}"
    rescue StandardError => e
      raise Error, "Unexpected error: #{e.message}"
    end
  end

  # Convenience method for JSON responses
  def json_completion(system_prompt:, user_prompt:, model: "gpt-4o-mini", temperature: 0.7, max_tokens: 300, retries: MAX_RETRIES)
    chat_completion(
      system_prompt: system_prompt,
      user_prompt: user_prompt,
      model: model,
      temperature: temperature,
      max_tokens: max_tokens,
      json_mode: true,
      retries: retries
    )
  end

  private

  def parse_json_response(content)
    # Try to extract JSON from response (in case there's extra text)
    json_match = content.match(/\{.*\}/m)
    json_text = json_match ? json_match[0] : content

    parsed = JSON.parse(json_text)
    parsed
  rescue JSON::ParserError => e
    # Try balanced brace extraction as fallback
    json_text = extract_balanced_json(content)
    if json_text
      JSON.parse(json_text)
    else
      raise InvalidResponseError, "Could not parse JSON from response: #{e.message}"
    end
  end

  def extract_balanced_json(text)
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

    nil
  end
end
