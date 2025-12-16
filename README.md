# Inbox Journal

A Rails 8 email-first AI journaling app. Receive AI-generated questions via email, reply to create journal entries, and build on your reflections over time.

## Features

- **Email-first journaling**: Receive AI-generated questions via email and reply to create entries
- **AI-generated prompts**: Two contextual questions per email based on your recent entries
- **Automatic analysis**: Entries are analyzed for summary, sentiment, emotion, and topics
- **Flexible scheduling**: Set your time zone, frequency (daily/weekdays/weekly), and send times
- **ActionMailbox integration**: Inbound emails are automatically processed and saved as entries
- **Session-based authentication**: Simple sign up and sign in (no Devise)

## Local Development

### Prerequisites

- Ruby 3.0 or higher
- PostgreSQL
- Bundler

### Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Setup the database:
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   ```

3. Configure environment variables:
   ```bash
   # Set OPENAI_API_KEY for AI features (optional)
   export OPENAI_API_KEY=your_key_here
   # Or create a .env file with:
   # OPENAI_API_KEY=your_key_here
   ```
   
   Get your OpenAI API key from: https://platform.openai.com/api-keys

4. Start the server:
   ```bash
   bin/server
   ```

5. Visit `http://localhost:3000`

### Local Demo with ActionMailbox Conductor

Since the app uses email for journaling, you can test the full flow locally using ActionMailbox Conductor:

1. **Sign up** for a new account at `http://localhost:3000`
2. **Complete onboarding** by setting:
   - Time zone (default: America/Chicago)
   - Email frequency (daily/weekdays/weekly)
   - Send times (comma-separated, e.g., "09:00,21:00")
3. **Send a test prompt**:
   - Click "Send me my next email now" on the dashboard
   - Or wait for the scheduled time
4. **View the outbound email**:
   - Check the Rails logs for the email content
   - Or use ActionMailbox Conductor at `/rails/conductor/action_mailbox/inbound_emails`
5. **Simulate an inbound reply**:
   - Go to `/rails/conductor/action_mailbox/inbound_emails`
   - Click "Deliver new inbound email"
   - Use the Reply-To address from the prompt email (format: `reply+TOKEN@localhost`)
   - Add your journal entry text in the body
   - Click "Deliver inbound email"
6. **View your entry**:
   - Check the dashboard to see your new journal entry
   - The entry will be automatically analyzed if `OPENAI_API_KEY` is set

### Environment Variables

**For AI features (optional but recommended):**
- `OPENAI_API_KEY` - Your OpenAI API key (get from https://platform.openai.com/api-keys)
  - Without this, the app uses fallback questions and basic analysis

**For email (required for production):**
- `MAIL_FROM` - Email address for sending prompts (default: "noreply@inboxjournal.com")
- `INBOUND_EMAIL_DOMAIN` - Domain for reply-to addresses (e.g., "yourdomain.com")
- `POSTMARK_API_TOKEN` - Postmark API token for production email delivery (recommended)
- `MAIL_HOST` - Host for mailer URL generation (e.g., "yourdomain.com")

**For database:**
- `DATABASE_URL` - PostgreSQL connection string (format: `postgresql://user:pass@localhost/dbname`)

**Optional:**
- `RAILS_ENV` - Environment (default: development)
- `RAILS_MAX_THREADS` - Database connection pool size (default: 5)
- `PORT` - Server port (default: 3000)
- `WEB_CONCURRENCY` - Puma workers (default: 2)

The app works without `OPENAI_API_KEY` - it will use fallback prompts and basic analysis.

## Email Setup

### Development

In development, emails are previewed in your browser instead of being sent:

1. **letter_opener_web** (preferred): Visit `/letter_opener` to view all sent emails in a web interface
2. **letter_opener** (fallback): Emails open in your default browser automatically

No email configuration needed for development.

### Production

For production, you need to configure real email delivery:

#### Option 1: Postmark (Recommended)

1. **Sign up for Postmark**: https://postmarkapp.com
2. **Create a Server**: In Postmark dashboard, create a new server
3. **Get API Token**: Copy your Server API Token
4. **Set Environment Variable**:
   ```bash
   POSTMARK_API_TOKEN=your_server_api_token_here
   ```

5. **Configure Inbound Email** (for reply processing):
   - In Postmark dashboard, go to your server → Inbound
   - Add your domain (e.g., `yourdomain.com`)
   - Configure DNS records as shown in Postmark
   - Set webhook URL: `https://yourdomain.com/rails/action_mailbox/postmark/inbound_emails`
   - Or use ActionMailbox ingress (see below)

6. **Set Required Environment Variables**:
   ```bash
   POSTMARK_API_TOKEN=your_server_api_token
   INBOUND_EMAIL_DOMAIN=yourdomain.com
   MAIL_FROM=noreply@yourdomain.com
   MAIL_HOST=yourdomain.com
   ```

#### Option 2: SMTP (Fallback)

If you prefer SMTP instead of Postmark:

```bash
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.com
SMTP_USERNAME=your_username
SMTP_PASSWORD=your_password
SMTP_AUTHENTICATION=plain
```

#### Inbound Email Processing

The app uses ActionMailbox to process email replies. You have two options:

**Option A: Postmark Webhook (Recommended)**
- Configure Postmark inbound webhook to: `https://yourdomain.com/rails/action_mailbox/postmark/inbound_emails`
- Postmark will POST emails to this endpoint
- No additional DNS configuration needed (beyond Postmark setup)

**Option B: ActionMailbox Ingress**
- Use ActionMailbox's built-in ingress
- Configure your email provider to forward emails to ActionMailbox
- See Rails ActionMailbox documentation for details

#### Reply-To Token Security

All prompt emails include a signed token in the Reply-To address:
- Format: `reply+TOKEN@yourdomain.com`
- Token contains: `[user_id, prompt_id, nonce, expiration_timestamp]`
- Expiration: 21 days
- Signed with Rails message verifier for security

#### Testing Email Delivery

1. **Development**: Check `/letter_opener` or browser popup
2. **Production**: 
   - Send a test prompt from dashboard
   - Check Postmark dashboard → Activity → Sent
   - Verify email arrives in inbox
   - Reply to test the inbound processing

## How It Works

1. **Onboarding**: After signup, users configure their time zone, email frequency, and send times
2. **Prompt generation**: The app generates two contextual questions based on the user's last 5 journal entries
3. **Email sending**: Prompts are sent via email with a signed token in the Reply-To address
4. **Email replies**: Users reply to the email, and ActionMailbox processes the inbound message
5. **Entry creation**: Replies are saved as journal entries linked to the original prompt
6. **Analysis**: Each entry is automatically analyzed for summary, sentiment, emotion, and topics
7. **Context building**: Future prompts use the last 5 entries to generate more relevant questions

## Deployment

This app is configured for deployment on Render.

### Render Deployment

1. Connect your repository to Render
2. Create a new Web Service
3. Render will automatically detect the `render.yaml` configuration
4. Environment variables are configured in `render.yaml`:
   - `DATABASE_URL` - Automatically provided by Render
   - `SECRET_KEY_BASE` - Automatically generated by Render
   - `OPENAI_API_KEY` - Add in Render dashboard under Environment Variables
   - `RAILS_ENV` - Set to production
   - `WEB_CONCURRENCY` - Set to 2
   - `MAIL_FROM` - Set your sending email address
   - `MAIL_DOMAIN` - Set your domain for reply-to addresses

5. To add `OPENAI_API_KEY` in Render:
   - Go to your service → Environment
   - Add new environment variable: `OPENAI_API_KEY`
   - Enter your API key value
   - Save changes

The app uses:
- PostgreSQL (via `DATABASE_URL`)
- Puma web server
- Solid Queue for background jobs
- ActionMailbox for email processing
- Standard Rails 8 production configuration

### Running Background Jobs and Scheduler

The app uses **Solid Queue** for background jobs and recurring tasks. The scheduler runs automatically when Solid Queue workers are running.

#### Development

1. **Start Solid Queue worker** (in a separate terminal):
   ```bash
   bin/jobs
   ```

2. **Or run in Puma** (if `SOLID_QUEUE_IN_PUMA=true`):
   ```bash
   bin/server
   ```
   The worker runs automatically alongside the web server.

3. **Check recurring tasks**:
   ```bash
   rails console
   > SolidQueue::RecurringTask.all
   ```

#### Production (Render/Heroku-like)

**Option A: Separate Worker Process (Recommended)**

1. **Add a Background Worker** in your hosting platform:
   - **Render**: Add a Background Worker service
   - **Heroku**: Use a worker dyno
   - **Command**: `bin/jobs`

2. **Environment Variables** (same as web service):
   - `DATABASE_URL`
   - `RAILS_ENV=production`
   - `OPENAI_API_KEY`
   - `POSTMARK_API_TOKEN`
   - `INBOUND_EMAIL_DOMAIN`
   - `MAIL_FROM`
   - `MAIL_HOST`

**Option B: In-Process Worker (Puma Plugin)**

If you want to run workers in the same process as Puma:

1. **Set environment variable**:
   ```bash
   SOLID_QUEUE_IN_PUMA=true
   ```

2. **Start server** (workers run automatically):
   ```bash
   bin/server
   ```

#### How Scheduling Works

1. **Recurring Task**: `SendScheduledPromptsJob` runs every 10 minutes (configured in `config/recurring.yml`)

2. **Job Logic**:
   - Finds users with `onboarding_complete = true`
   - Checks if `next_prompt_at <= now` (in user's timezone)
   - Idempotency: Skips if `last_prompt_sent_at` is within the scheduled window (±1 hour)
   - Sends prompt via `PromptSender`
   - Updates `last_prompt_sent_at` and computes `next_prompt_at`

3. **Timezone Handling**: All scheduling is timezone-aware using the user's `time_zone` setting

#### Manual Testing

```bash
# Run the job manually
rails console
> SendScheduledPromptsJob.perform_now

# Check which users are due
> User.where(onboarding_complete: true).where("next_prompt_at <= ?", Time.current)

# Force a user's next prompt time
> user = User.first
> user.update(next_prompt_at: 1.minute.ago)
> SendScheduledPromptsJob.perform_now
```

#### Monitoring

- **Check job status**: Visit `/rails/jobs` (if enabled) or use Rails console
- **View recurring tasks**: `SolidQueue::RecurringTask.all`
- **Check logs**: Look for "SendScheduledPromptsJob completed" messages

## License

MIT License - see [LICENSE.txt](LICENSE.txt)
