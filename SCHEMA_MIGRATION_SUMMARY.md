# Database Schema Migration Summary - Dabble-like Schema

## Overview
This document summarizes the database schema changes to transform the app to a Dabble-like structure while preserving existing data.

## Migrations Created

### 1. `20251213000001_update_users_for_dabble_schema.rb`
**Changes to `users` table:**
- ✅ Added `onboarding_complete` (boolean, default: false)
- ✅ Added `schedule_frequency` (string enum: daily/weekdays/weekly)
- ✅ Added `schedule_time` (time)
- ✅ Added `last_prompt_sent_at` (datetime)
- ✅ Added `streak_count` (integer, default: 0)
- ✅ Added `last_entry_at` (datetime)

**Data Migration:**
- Copies `prompt_frequency` → `schedule_frequency`
- Extracts first time from `send_times` → `schedule_time`
- Calculates `onboarding_complete` from existing fields
- Computes initial `streak_count` from existing entries
- Sets `last_entry_at` from most recent entry

**Backward Compatibility:**
- Old fields (`prompt_frequency`, `send_times`) remain for migration period
- User model supports both old and new fields

### 2. `20251213000002_update_prompts_for_dabble_schema.rb`
**Changes to `prompts` table:**
- ✅ Added `subject` (string)
- ✅ Added `status` (string enum: draft/sent/replied, default: "draft")
- ✅ Added `replied_at` (datetime)
- ✅ Added `follow_up_sent_at` (datetime)
- ✅ Added `prompt_type` (string enum: daily/weekly/adhoc)
- ✅ Added `idempotency_key` (string)
- ✅ Added unique index on `[user_id, idempotency_key]`

**Data Migration:**
- Sets `status` based on `sent_at` (sent if sent_at present, else draft)
- Sets `replied_at` from first journal entry for the prompt
- Updates `status` to "replied" if `replied_at` is set
- Sets `prompt_type` based on `parent_prompt_id` (adhoc for follow-ups)
- Generates `idempotency_key` from user_id and timestamp

**Backward Compatibility:**
- Old fields (`question_1`, `question_2`, `body`) remain
- Services use both old and new fields

### 3. `20251213000003_update_journal_entries_for_dabble_schema.rb`
**Changes to `journal_entries` table:**
- ✅ Added `word_count` (integer)
- ✅ Added `cleaned_body` (text)
- ✅ Added index on `[user_id, received_at]`

**Data Migration:**
- Calculates `word_count` from existing `body`
- Sets `cleaned_body` = `body` initially (will be updated by EmailSanitizer going forward)

### 4. `20251213000004_update_entry_analyses_for_dabble_schema.rb`
**Changes to `entry_analyses` table:**
- ✅ Added `tags` (jsonb array)
- ✅ Added `key_themes` (jsonb array)
- ✅ Added GIN index on `tags` for efficient queries

**Data Migration:**
- Converts comma-separated `keywords` string → `tags` JSON array
- Initializes `key_themes` as empty array
- Initializes `tags` as empty array if keywords were null

**Backward Compatibility:**
- `keywords` field remains (not removed)
- EntryAnalysis model provides `keywords` getter/setter that converts to/from `tags`

## Model Updates

### User Model
- ✅ Added `schedule_frequency` enum (daily/weekdays/weekly)
- ✅ Added validations for `streak_count`
- ✅ Updated `onboarding_complete?` to use database column
- ✅ Updated `update_next_prompt_at!` to support both old and new fields
- ✅ Added `update_onboarding_complete` callback

### Prompt Model
- ✅ Added `status` enum (draft/sent/replied)
- ✅ Added `prompt_type` enum (daily/weekly/adhoc)
- ✅ Added validation for `idempotency_key` uniqueness (scoped to user_id)
- ✅ Added `mark_as_sent!` and `mark_as_replied!` methods
- ✅ Added callbacks for status transitions
- ✅ Auto-generates `idempotency_key` on create

### JournalEntry Model
- ✅ Added `source` enum (email/web)
- ✅ Added validation for `word_count`
- ✅ Added `calculate_word_count` callback
- ✅ Added `update_user_last_entry_at` callback
- ✅ Added `update_prompt_replied_at` callback

### EntryAnalysis Model
- ✅ Added validation for `sentiment` (positive/neutral/negative)
- ✅ Added `tags` and `key_themes` JSON helpers
- ✅ Added backward-compatible `keywords` getter/setter

### EmailMessage Model
- ✅ Added `direction` enum (inbound/outbound)
- ✅ Added validations for `direction` and `subject`

## Service Updates

All services updated to:
- ✅ Use `cleaned_body` when available, fallback to `body`
- ✅ Use `tags` (JSON array) instead of `keywords` (string), with backward compatibility
- ✅ Set proper `subject`, `status`, `prompt_type` when creating prompts
- ✅ Update `last_prompt_sent_at` on user when sending prompts
- ✅ Use `mark_as_sent!` and `mark_as_replied!` methods

## Indices Added

1. **prompts**: Unique index on `[user_id, idempotency_key]` - prevents duplicate prompts
2. **journal_entries**: Index on `[user_id, received_at]` - efficient queries for user entries
3. **entry_analyses**: GIN index on `tags` - efficient JSON array queries

## Status Transitions

Prompt status transitions are enforced:
- `draft` → `sent` (when email is sent)
- `sent` → `replied` (when user replies)
- Status automatically updates via callbacks

## Running the Migrations

```bash
# Run all migrations
rails db:migrate

# Rollback if needed
rails db:rollback STEP=4
```

## Testing the Migration

1. **Verify data migration:**
   ```ruby
   # Check users
   User.all.each { |u| puts "#{u.email}: onboarding=#{u.onboarding_complete}, streak=#{u.streak_count}" }
   
   # Check prompts
   Prompt.all.each { |p| puts "Prompt #{p.id}: status=#{p.status}, type=#{p.prompt_type}" }
   
   # Check entry_analyses
   EntryAnalysis.all.each { |e| puts "Tags: #{e.tags}, Keywords: #{e.keywords}" }
   ```

2. **Test backward compatibility:**
   - Services should work with both old and new field names
   - `keywords` getter/setter should work on EntryAnalysis

3. **Test new features:**
   - Create prompt with `idempotency_key` - should prevent duplicates
   - Check status transitions work correctly
   - Verify `cleaned_body` is populated for new entries

## Notes

- All migrations are reversible (have `down` methods)
- Existing data is preserved and migrated
- Backward compatibility maintained for transition period
- Old fields can be removed in a future migration after full transition
