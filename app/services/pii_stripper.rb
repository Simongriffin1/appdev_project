class PIIStripper
  # Common email patterns
  EMAIL_REGEX = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/

  # Common phone number patterns (US format)
  PHONE_REGEX = /\b(?:\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})\b/

  # Common credit card patterns (basic detection)
  CREDIT_CARD_REGEX = /\b(?:\d[ -]*?){13,16}\b/

  # Common SSN patterns
  SSN_REGEX = /\b\d{3}-\d{2}-\d{4}\b/

  # Common names (basic detection - can be improved)
  # This is a simple approach - in production, you might want a more sophisticated solution
  COMMON_NAME_PATTERNS = [
    /\b(?:Mr|Mrs|Ms|Dr|Prof)\.?\s+[A-Z][a-z]+\s+[A-Z][a-z]+\b/, # Titles with names
  ]

  def self.strip(text)
    return "" if text.blank?

    stripped = text.dup

    # Remove emails
    stripped.gsub!(EMAIL_REGEX, "[email redacted]")

    # Remove phone numbers
    stripped.gsub!(PHONE_REGEX, "[phone redacted]")

    # Remove credit card numbers
    stripped.gsub!(CREDIT_CARD_REGEX, "[card redacted]")

    # Remove SSNs
    stripped.gsub!(SSN_REGEX, "[ssn redacted]")

    # Remove common name patterns (conservative - only obvious patterns)
    COMMON_NAME_PATTERNS.each do |pattern|
      stripped.gsub!(pattern, "[name redacted]")
    end

    # Remove URLs that might contain PII
    stripped.gsub!(%r{https?://[^\s]+}, "[url redacted]")

    stripped
  end

  # Strip PII from a hash of data (useful for context)
  def self.strip_from_hash(data)
    return {} unless data.is_a?(Hash)

    data.transform_values do |value|
      case value
      when String
        strip(value)
      when Array
        value.map { |v| v.is_a?(String) ? strip(v) : v }
      when Hash
        strip_from_hash(value)
      else
        value
      end
    end
  end
end
