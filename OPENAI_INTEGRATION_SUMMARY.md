# OpenAI Integration Summary

## Overview
This document summarizes the centralized OpenAI integration with retries, timeouts, PII stripping, and graceful error handling.

## New Services Created

### 1. `app/services/openai_client.rb`
**Centralized OpenAI client service with:**
- ✅ Retry logic with exponential backoff (max 3 retries)
- ✅ Timeout handling (30 seconds)
- ✅ Structured JSON response support
- ✅ Error handling for rate limits, server errors, timeouts
- ✅ Custom error classes: `Error`, `TimeoutError`, `APIError`, `InvalidResponseError`

**Methods:**
- `chat_completion` - Main method for chat completions
- `json_completion` - Convenience method for JSON responses

**Features:**
- Automatic retry on rate limits and server errors
- Exponential backoff (1s, 2s, 4s delays)
- JSON parsing with fallback extraction
- Balanced brace matching for nested JSON

### 2. `app/services/pii_stripper.rb`
**PII Stripping Service:**
- ✅ Removes email addresses
- ✅ Removes phone numbers (US format)
- ✅ Removes credit card numbers
- ✅ Removes SSNs
- ✅ Removes URLs
- ✅ Removes common name patterns (conservative)

**Methods:**
- `strip(text)` - Strip PII from a string
- `strip_from_hash(data)` - Strip PII from hash values

## Refactored Services

### 1. `app/services/prompt_generator.rb`
**Updates:**
- ✅ Uses `OpenAIClient` instead of direct OpenAI calls
- ✅ Strips PII from context before sending to OpenAI
- ✅ Supports tone preference (casual/formal/warm)
- ✅ Generates idempotency key for scheduled window
- ✅ Enforces 60-word total limit for questions
- ✅ Uses last 7 days of entries (not just 5)
- ✅ Returns draft prompt with idempotency_key
- ✅ Graceful fallback to non-AI prompts on errors

**Output:**
- `subject` - Short subject line (max 10 words)
- `question_1` - First question
- `question_2` - Second question
- Total word count <= 60 words

**Idempotency:**
- Key generated from `user_id` + scheduled window (hour)
- Prevents duplicate prompts for same scheduled time

### 2. `app/services/entry_analysis_generator.rb`
**Updates:**
- ✅ Uses `OpenAIClient` instead of direct OpenAI calls
- ✅ Strips PII from entry body before sending to OpenAI
- ✅ Validates and enforces output format
- ✅ Ensures 3-6 tags (fills if fewer)
- ✅ Ensures 2-3 sentence summary
- ✅ Graceful fallback to non-AI analysis on errors

**Output:**
- `summary` - 2-3 sentences (validated)
- `tags` - 3-6 topic labels (JSON array)
- `sentiment` - positive/neutral/negative
- `key_themes` - First 3 tags as key themes
- `emotion` - Main emotion word

### 3. `app/services/follow_up_question_generator.rb`
**Updates:**
- ✅ Uses `OpenAIClient` instead of direct OpenAI calls
- ✅ Strips PII from prompts and analysis
- ✅ Graceful fallback on errors

## Error Handling

### Graceful Degradation
All services implement graceful error handling:
1. **Try OpenAI first** (if API key present)
2. **Log errors** without crashing
3. **Fallback to non-AI** alternatives
4. **Continue processing** even if OpenAI fails

### Error Logging
- All errors logged with class and message
- Backtraces logged in development
- Errors don't crash jobs or mailboxes

### Jobs Updated
- `SendScheduledPromptsJob` - Handles errors per user, continues processing
- `FollowUpQuestionJob` - Handles errors gracefully, doesn't crash

### Services Updated
- `PromptSender` - Handles generation and email errors separately
- `JournalReplyMailbox` - Handles analysis errors without bouncing email

## PII Protection

### What's Stripped
- Email addresses → `[email redacted]`
- Phone numbers → `[phone redacted]`
- Credit card numbers → `[card redacted]`
- SSNs → `[ssn redacted]`
- URLs → `[url redacted]`
- Common name patterns → `[name redacted]`

### Where Applied
- **PromptGenerator**: Context summaries, last prompts
- **EntryAnalysisGenerator**: Entry body before analysis
- **FollowUpQuestionGenerator**: Entry body, analysis summary, prompts

## Configuration

### Environment Variables
- `OPENAI_API_KEY` - Required for AI features (dotenv supported)
- Falls back to non-AI prompts/analysis if not set

### Caching
- **PromptGenerator**: 1 hour cache (based on user + context hash)
- **EntryAnalysisGenerator**: 24 hour cache (based on entry content)
- **FollowUpQuestionGenerator**: 1 hour cache (based on entry content)

## Testing

### Manual Testing
```ruby
# Test OpenAI client
client = OpenAIClient.new
result = client.json_completion(
  system_prompt: "You are helpful.",
  user_prompt: "Say hello in JSON with key 'message'",
  json_mode: true
)

# Test PII stripping
PIIStripper.strip("Contact me at john@example.com or 555-1234")

# Test PromptGenerator
user = User.first
generator = PromptGenerator.new(user)
prompt = generator.generate!

# Test EntryAnalysisGenerator
entry = JournalEntry.first
generator = EntryAnalysisGenerator.new(entry)
analysis = generator.generate!
```

### Error Scenarios
1. **OpenAI API down**: Should fallback to non-AI prompts
2. **Rate limit**: Should retry with exponential backoff
3. **Timeout**: Should retry up to 3 times, then fallback
4. **Invalid JSON**: Should extract JSON or fallback
5. **Missing API key**: Should use fallback immediately

## Requirements Met

✅ **Single client service** (`OpenAIClient`) with retries, timeouts, JSON support  
✅ **PromptGenerator** with 7-day context, <=60 words, tone preference, idempotency  
✅ **EntryAnalysisGenerator** with 2-3 sentence summary, 3-6 tags, sentiment, themes  
✅ **PII stripping** in all prompts sent to OpenAI  
✅ **Graceful error handling** with fallbacks  
✅ **Logging without crashing** jobs  

## Notes

- All services maintain backward compatibility
- Fallback prompts/analysis are deterministic and always available
- PII stripping is conservative (may miss some patterns)
- Caching reduces API calls and costs
- Idempotency keys prevent duplicate prompts for scheduled windows
