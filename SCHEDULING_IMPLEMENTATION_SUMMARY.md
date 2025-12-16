# Automated Prompt Scheduling Implementation

## Overview
This document summarizes the automated prompt scheduling system that sends journal prompts to users at their scheduled times.

## Architecture

### Technology Stack
- **ActiveJob** with **Solid Queue** (Rails 8 built-in)
- **Recurring Tasks** via `config/recurring.yml`
- **No external dependencies** (no Sidekiq, no cron setup needed)

### Why Solid Queue?
- ✅ Built into Rails 8
- ✅ No additional infrastructure (uses PostgreSQL)
- ✅ Recurring tasks built-in
- ✅ Works on Render, Heroku, and similar platforms
- ✅ Can run in-process with Puma or as separate worker

## Implementation

### 1. Recurring Job Configuration

**File**: `config/recurring.yml`

```yaml
production:
  send_scheduled_prompts:
    class: SendScheduledPromptsJob
    queue: default
    schedule: every 10 minutes
    description: "Send scheduled journal prompts to users"
```

**Schedule**: Runs every 10 minutes (middle of 5-15 minute range)

### 2. Job: `SendScheduledPromptsJob`

**Location**: `app/jobs/send_scheduled_prompts_job.rb`

**Logic**:
1. Finds users with `onboarding_complete = true`
2. Filters users where `next_prompt_at <= now` (UTC)
3. For each user:
   - Checks timezone-aware scheduling
   - Verifies idempotency (last_prompt_sent_at in window)
   - Sends prompt via `PromptSender`
   - Logs results

**Idempotency**:
- Uses `last_prompt_sent_at` to check if prompt already sent
- Window: scheduled time ± 1 hour
- Prevents duplicate sends if job runs multiple times

**Timezone Handling**:
- All checks done in user's timezone
- `next_prompt_at` stored in UTC, converted for comparison
- Accurate scheduling regardless of server timezone

### 3. Service: `PromptSender`

**Location**: `app/services/prompt_sender.rb`

**Responsibilities**:
- Generates prompt via `PromptGenerator`
- Sends email via `PromptMailer`
- Updates `last_prompt_sent_at` (critical for idempotency)
- Computes `next_prompt_at` via `user.update_next_prompt_at!`
- Logs email message

### 4. User Model: `update_next_prompt_at!`

**Location**: `app/models/user.rb`

**Logic**:
- Uses `schedule_frequency` (daily/weekdays/weekly)
- Uses `schedule_time` (single time) or `send_times` (comma-separated)
- Respects user's `time_zone`
- Calculates next send time based on frequency:
  - **daily**: Next occurrence of schedule_time
  - **weekdays**: Next weekday occurrence
  - **weekly**: Same day next week

## Running the Scheduler

### Development

**Option 1: Separate Worker Process** (Recommended)
```bash
# Terminal 1: Web server
bin/server

# Terminal 2: Background jobs
bin/jobs
```

**Option 2: In-Process** (Puma Plugin)
```bash
# Set environment variable
export SOLID_QUEUE_IN_PUMA=true

# Start server (workers run automatically)
bin/server
```

### Production

**Option A: Separate Worker Process** (Recommended for scale)

1. **Add Background Worker** in hosting platform:
   - **Render**: Create Background Worker service
   - **Heroku**: Add worker dyno
   - **Command**: `bin/jobs`

2. **Environment Variables** (same as web service):
   - All standard env vars (DATABASE_URL, OPENAI_API_KEY, etc.)

**Option B: In-Process** (Single server)

1. **Set environment variable**:
   ```bash
   SOLID_QUEUE_IN_PUMA=true
   ```

2. **Start server**:
   ```bash
   bin/server
   ```

Workers and recurring tasks run automatically.

## How It Works

### Scheduling Flow

1. **User completes onboarding**:
   - Sets `time_zone`, `schedule_frequency`, `schedule_time`
   - `onboarding_complete` set to `true`
   - `next_prompt_at` calculated and set

2. **Recurring job runs** (every 10 minutes):
   - Finds users with `next_prompt_at <= now`
   - Checks each user's timezone
   - Verifies idempotency

3. **Prompt sent**:
   - `PromptSender` generates and sends prompt
   - `last_prompt_sent_at` updated
   - `next_prompt_at` recalculated

4. **Next cycle**:
   - Job runs again in 10 minutes
   - Users with new `next_prompt_at` are checked
   - Process repeats

### Idempotency Example

**Scenario**: Job runs twice within 10 minutes

1. **First run** (10:00 AM):
   - User's `next_prompt_at` = 10:00 AM
   - `last_prompt_sent_at` = nil
   - ✅ Prompt sent
   - `last_prompt_sent_at` = 10:00 AM

2. **Second run** (10:05 AM):
   - User's `next_prompt_at` = 10:00 AM (not updated yet)
   - `last_prompt_sent_at` = 10:00 AM
   - Window: 9:00 AM - 11:00 AM
   - ✅ `last_prompt_sent_at` (10:00 AM) is in window
   - ⏭️ Skipped (idempotency)

3. **Third run** (10:10 AM):
   - `next_prompt_at` already updated to next scheduled time
   - User not in due list
   - ⏭️ Skipped

## Testing

### Manual Testing

```ruby
# In Rails console

# Check due users
User.where(onboarding_complete: true)
    .where("next_prompt_at <= ?", Time.current)

# Force a user to be due
user = User.first
user.update(next_prompt_at: 1.minute.ago)
user.update(last_prompt_sent_at: nil) # Clear idempotency

# Run job manually
SendScheduledPromptsJob.perform_now

# Check results
user.reload
user.last_prompt_sent_at # Should be set
user.next_prompt_at # Should be updated
```

### Test Scenarios

1. **Normal scheduling**: User receives prompt at scheduled time
2. **Idempotency**: Duplicate job runs don't send duplicate prompts
3. **Timezone handling**: User in PST gets prompt at correct local time
4. **Frequency handling**: Daily/weekdays/weekly schedules work correctly
5. **Multiple users**: Job processes all due users efficiently

## Monitoring

### Check Job Status

```ruby
# Rails console
SolidQueue::RecurringTask.all
SolidQueue::Job.where(class_name: "SendScheduledPromptsJob").order(created_at: :desc).limit(10)
```

### Logs

Look for:
- `"SendScheduledPromptsJob completed: X sent, Y skipped, Z errors"`
- `"Sent scheduled prompt to user X"`
- `"Skipped user X - already sent in this window"`

### Common Issues

1. **No prompts being sent**:
   - Check `onboarding_complete` is true
   - Verify `next_prompt_at` is set
   - Check timezone is correct
   - Ensure worker is running (`bin/jobs`)

2. **Duplicate prompts**:
   - Check `last_prompt_sent_at` is being updated
   - Verify idempotency logic is working
   - Check job isn't running too frequently

3. **Wrong timezone**:
   - Verify user's `time_zone` is set correctly
   - Check `next_prompt_at` calculation uses timezone

## Requirements Met

✅ **Automated scheduling** via recurring job  
✅ **Runs every 10 minutes** (within 5-15 minute range)  
✅ **Checks onboarding_complete** and next_prompt_at  
✅ **Timezone-aware** scheduling  
✅ **Idempotency** using last_prompt_sent_at  
✅ **Updates next_prompt_at** after sending  
✅ **Solid Queue** (simplest for Render/Heroku)  
✅ **Documented** how to run workers  

## Deployment Notes

### Render

1. **Web Service**: Runs `bin/server` (or `bin/rails server`)
2. **Background Worker**: Create separate service running `bin/jobs`
3. **Environment**: Set `SOLID_QUEUE_IN_PUMA=false` (or omit)

### Heroku

1. **Web Dyno**: `bin/rails server`
2. **Worker Dyno**: `bin/jobs`
3. **Procfile**:
   ```
   web: bin/rails server
   worker: bin/jobs
   ```

### Single Server

Set `SOLID_QUEUE_IN_PUMA=true` and run `bin/server` - workers run in-process.
