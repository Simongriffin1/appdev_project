# Inbound Email Processing Summary

## Overview
This document summarizes the robust inbound email reply processing implementation with idempotency, email cleaning, follow-up logic, and streak updates.

## Key Features

### 1. Idempotency
- **Message-ID Hash**: Uses email Message-ID header to prevent duplicate processing
- **Database Index**: Unique index on `message_id_hash` in `journal_entries` table
- **Fallback**: If Message-ID not available, generates hash from email headers and content
- **Silent Skip**: Duplicate emails are silently skipped (no error, no duplicate entry)

### 2. Email Body Cleaning
Enhanced `EmailSanitizer` service removes:
- ✅ **HTML noise**: Strips HTML tags, scripts, styles
- ✅ **Quoted reply history**: Removes "On [date] wrote:" patterns
- ✅ **Email signatures**: Detects and removes signature separators (--, ---, etc.)
- ✅ **Quoted lines**: Removes lines starting with `>` or `|`
- ✅ **Email headers**: Removes leaked headers (From, To, Subject, etc.)
- ✅ **HTML entities**: Decodes common entities (&nbsp;, &amp;, etc.)
- ✅ **Multiple blank lines**: Normalizes whitespace

**Lightweight**: Pure Ruby implementation, no heavy dependencies

### 3. Follow-Up Question Logic
- **Condition**: Body < 30 words AND follow-up not already sent
- **Synchronous**: Short replies trigger immediate follow-up (threaded)
- **Asynchronous**: Longer replies process follow-up in background job
- **Threaded**: Follow-up emails maintain conversation thread

### 4. Prompt Status Updates
- **replied_at**: Set when first reply received
- **status**: Automatically updated to "replied" via `mark_as_replied!`
- **Idempotent**: Only updates if not already set

### 5. User Streak Updates
- **StreakUpdater Service**: Dedicated service for streak calculation
- **Automatic**: Updates streak when entry is created
- **Efficient**: Only updates if streak count changed
- **Calculation**: Counts consecutive days with entries

## Implementation Details

### Migration
**File**: `db/migrate/20251213000005_add_message_id_hash_to_journal_entries.rb`
- Adds `message_id_hash` column to `journal_entries`
- Creates unique index for idempotency

### Mailbox: `JournalReplyMailbox`
**Main Method**: `process` (alias for `journal_reply`)

**Processing Flow**:
1. Extract and verify token
2. Find user and prompt
3. Check idempotency (Message-ID hash)
4. Extract and clean email body
5. Create journal entry with cleaned body
6. Log email message
7. Mark prompt as replied
8. Update user streak
9. Generate entry analysis
10. Send follow-up if needed (< 30 words)

**Error Handling**:
- All errors are logged but don't bounce emails
- Graceful fallbacks for analysis and follow-up generation
- Idempotency prevents duplicate processing

### Services

#### `EmailSanitizer`
Enhanced with:
- HTML stripping (lightweight, no dependencies)
- HTML entity decoding
- Email header removal
- Better signature detection

#### `StreakUpdater`
New service for streak calculation:
- Calculates consecutive days with entries
- Updates `streak_count` on user
- Efficient (only updates if changed)

## Database Changes

### `journal_entries` table
- `message_id_hash` (string, indexed, unique)
  - Stores MD5 hash of Message-ID or email content
  - Used for idempotency checks

## Processing Logic

### Idempotency Check
```ruby
message_id_hash = generate_message_id_hash
existing_entry = JournalEntry.find_by(message_id_hash: message_id_hash)
return if existing_entry # Skip duplicate
```

### Follow-Up Decision
```ruby
if word_count < 30 && !follow_up_already_sent?(prompt)
  # Send synchronously (threaded)
  follow_up_generator.generate_and_send!
else
  # Process asynchronously
  FollowUpQuestionJob.perform_later(journal_entry.id)
end
```

### Prompt Status Update
```ruby
prompt.update_column(:replied_at, journal_entry.received_at) if prompt.replied_at.nil?
prompt.mark_as_replied! unless prompt.replied?
```

### Streak Update
```ruby
StreakUpdater.update_for_user(user)
```

## Error Handling

All processing steps have error handling:
- **Token verification**: Returns bounce if invalid
- **User/prompt lookup**: Returns bounce if not found
- **Body cleaning**: Falls back to raw body if cleaning fails
- **Entry creation**: Validates and handles errors
- **Analysis generation**: Logs errors, continues processing
- **Follow-up generation**: Logs errors, doesn't fail processing
- **Streak update**: Logs errors, doesn't fail processing

## Testing

### Manual Testing
1. **Send a reply email** to a prompt
2. **Check logs** for processing steps
3. **Verify entry created** with cleaned body
4. **Check prompt status** updated to "replied"
5. **Verify streak** updated
6. **Send duplicate email** - should be silently skipped
7. **Send short reply** (< 30 words) - should trigger immediate follow-up

### Test Scenarios
- ✅ Normal reply processing
- ✅ Duplicate email (idempotency)
- ✅ Short reply (< 30 words) with follow-up
- ✅ Long reply (no immediate follow-up)
- ✅ HTML email cleaning
- ✅ Quoted history removal
- ✅ Signature removal
- ✅ Expired token handling
- ✅ Invalid token handling

## Requirements Met

✅ **Robust mailbox processing** with `process` method  
✅ **Token verification** with expiration check  
✅ **Email body cleaning** (quoted history, signatures, HTML)  
✅ **Follow-up logic** (< 30 words, synchronous if needed)  
✅ **Prompt status updates** (replied_at, status=replied)  
✅ **User streak updates** (automatic on entry creation)  
✅ **Idempotency** (Message-ID hash, prevents duplicates)  
✅ **Lightweight email cleaning** (pure Ruby, no heavy deps)  

## Notes

- Message-ID hash is optional (allows nil for entries without Message-ID)
- Follow-up is sent synchronously only for short replies (< 30 words)
- All processing is idempotent and safe to retry
- Error handling ensures emails are never lost
- Streak calculation is efficient and cached
