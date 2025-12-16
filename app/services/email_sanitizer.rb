class EmailSanitizer
  # Remove quoted history, signatures, HTML noise, and other email artifacts from the body
  def self.sanitize(body)
    return "" if body.blank?

    # First, convert HTML to plain text if needed
    body = strip_html(body) if html_content?(body)

    # Remove common email quote markers
    # Matches patterns like:
    # - "On [date], [person] wrote:"
    # - "From: [email]"
    # - "Sent: [date]"
    # - "> " (quoted lines)
    # - "-----Original Message-----"
    # - Common signature separators like "-- " or "---"
    
    lines = body.split("\n")
    sanitized_lines = []
    in_quoted_section = false
    
    lines.each do |line|
      stripped = line.strip
      
      # Skip empty lines if we're in a quoted section
      next if in_quoted_section && stripped.empty?
      
      # Detect start of quoted sections
      if matches_quote_start?(stripped)
        in_quoted_section = true
        next
      end
      
      # Detect signature separators (common patterns)
      if matches_signature_separator?(stripped)
        break # Stop processing at signature
      end
      
      # Skip lines that are clearly quoted (start with > or |)
      if in_quoted_section || stripped.start_with?(">", "|")
        in_quoted_section = true
        next
      end
      
      # If we hit a non-quoted line after being in quoted section, we're out
      if in_quoted_section && !stripped.start_with?(">", "|")
        in_quoted_section = false
      end
      
      sanitized_lines << line
    end
    
    # Join and clean up
    result = sanitized_lines.join("\n")
    
    # Remove trailing whitespace and multiple blank lines
    result = result.gsub(/\n{3,}/, "\n\n").strip
    
    # Remove any remaining HTML entities
    result = decode_html_entities(result)
    
    # Remove email headers that might have leaked through
    result = remove_email_headers(result)
    
    result
  end

  private

  def self.matches_quote_start?(line)
    # Common patterns for email quote starts
    line.match?(/\A(On\s+.+\s+wrote:?|From:?\s+|Sent:?\s+|Date:?\s+|-----Original Message-----|-----Forwarded Message-----)/i)
  end

  def self.matches_signature_separator?(line)
    # Common signature separators
    line.match?(/\A(-{2,3}|_{2,3}|={2,3})\s*$/) || 
    line.match?(/\A--\s+$/) ||
    line.match?(/\A(Sent from|Sent via|Get Outlook|Get Gmail|Best regards|Sincerely|Thanks|Thank you)/i)
  end

  def self.html_content?(text)
    text.match?(/<[a-z][\s\S]*>/i)
  end

  def self.strip_html(html)
    # Simple HTML stripping - remove tags and decode entities
    # This is a lightweight approach, no heavy dependencies
    text = html.dup
    
    # Remove script and style tags with their content
    text.gsub!(/<script[\s\S]*?<\/script>/i, "")
    text.gsub!(/<style[\s\S]*?<\/style>/i, "")
    
    # Remove HTML tags
    text.gsub!(/<[^>]+>/, "")
    
    # Decode common HTML entities
    text = decode_html_entities(text)
    
    # Clean up whitespace
    text.gsub!(/\s+/, " ")
    text.gsub!(/\n\s*\n/, "\n")
    
    text.strip
  end

  def self.decode_html_entities(text)
    # Decode common HTML entities (lightweight, no dependencies)
    text.gsub(/&nbsp;/, " ")
         .gsub(/&amp;/, "&")
         .gsub(/&lt;/, "<")
         .gsub(/&gt;/, ">")
         .gsub(/&quot;/, '"')
         .gsub(/&#39;/, "'")
         .gsub(/&apos;/, "'")
         .gsub(/&#x27;/, "'")
         .gsub(/&#x2F;/, "/")
         .gsub(/&#(\d+);/) { |m| [$1.to_i].pack("U") rescue m }
         .gsub(/&#x([0-9a-f]+);/i) { |m| [$1.to_i(16)].pack("U") rescue m }
  end

  def self.remove_email_headers(text)
    # Remove any email headers that might have leaked through
    lines = text.split("\n")
    cleaned_lines = []
    skip_headers = false
    
    lines.each do |line|
      # Stop skipping if we hit a blank line (end of headers)
      if line.strip.empty?
        skip_headers = false
        cleaned_lines << line unless skip_headers
        next
      end
      
      # Skip common email header patterns
      if line.match?(/^(From|To|Subject|Date|CC|BCC|Reply-To|Message-ID):/i)
        skip_headers = true
        next
      end
      
      cleaned_lines << line unless skip_headers
    end
    
    cleaned_lines.join("\n")
  end
end
