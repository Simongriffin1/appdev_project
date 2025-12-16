# Production Readiness Checklist

## Pre-Deployment Checklist

### ✅ Environment Variables

**Required for Production:**
- [ ] `SECRET_KEY_BASE` - Rails secret (auto-generated on Render/Heroku)
- [ ] `DATABASE_URL` - PostgreSQL connection string
- [ ] `RAILS_ENV=production`
- [ ] `POSTMARK_API_TOKEN` - For email delivery (recommended)
- [ ] `INBOUND_EMAIL_DOMAIN` - Domain for reply-to addresses
- [ ] `MAIL_FROM` - Email address for sending prompts
- [ ] `MAIL_HOST` - Host for mailer URL generation

**Optional but Recommended:**
- [ ] `OPENAI_API_KEY` - For AI features (fallbacks work without it)
- [ ] `ROLLBAR_ACCESS_TOKEN` - For error reporting
- [ ] `RAILS_LOG_LEVEL=info` - Log level (default: info)
- [ ] `RAILS_MAX_THREADS=5` - Database connection pool
- [ ] `WEB_CONCURRENCY=2` - Puma workers

**For SMTP (if not using Postmark):**
- [ ] `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_USERNAME`, `SMTP_PASSWORD`

### ✅ Database

- [ ] Run migrations: `bin/rails db:migrate`
- [ ] Verify database connection works
- [ ] Check indexes are created (especially for `journal_entries.message_id_hash`)

### ✅ Email Configuration

**Outbound Email (Postmark):**
- [ ] Postmark account created
- [ ] Server API token set in environment
- [ ] Sender email verified in Postmark
- [ ] Test email sending works

**Inbound Email (ActionMailbox):**
- [ ] Domain configured in Postmark (or your email provider)
- [ ] MX records configured (points to Postmark or your provider)
- [ ] Webhook URL configured: `https://yourdomain.com/rails/action_mailbox/postmark/inbound_emails`
- [ ] Or use ActionMailbox ingress (see ActionMailbox Setup below)

### ✅ Background Jobs

- [ ] Solid Queue worker running (`bin/jobs` or `SOLID_QUEUE_IN_PUMA=true`)
- [ ] Recurring tasks configured (`config/recurring.yml`)
- [ ] Verify `SendScheduledPromptsJob` runs every 10 minutes

### ✅ Security

- [ ] `SECRET_KEY_BASE` is set (never commit to git)
- [ ] API keys not logged (filtered in `filter_parameter_logging.rb`)
- [ ] SSL/HTTPS enabled (force_ssl in production.rb)
- [ ] Database credentials secure
- [ ] No secrets in code or logs

### ✅ Error Reporting

- [ ] Rails logger configured (STDOUT in production)
- [ ] Optional: Rollbar configured if `ROLLBAR_ACCESS_TOKEN` set
- [ ] Error handling in place (all services have begin/rescue blocks)

### ✅ Testing

- [ ] Run smoke tests locally (see Testing section)
- [ ] Verify email sending works
- [ ] Verify inbound email processing works
- [ ] Test manual prompt sending
- [ ] Test scheduled prompt sending

## ActionMailbox Inbound Email Setup

### Option 1: Postmark Webhook (Recommended)

1. **Configure Postmark Inbound:**
   - Go to Postmark dashboard → Your Server → Inbound
   - Add your domain (e.g., `yourdomain.com`)
   - Configure DNS MX records as shown in Postmark
   - Set webhook URL: `https://yourdomain.com/rails/action_mailbox/postmark/inbound_emails`

2. **Verify DNS:**
   ```bash
   # Check MX record
   dig MX yourdomain.com
   # Should point to Postmark's inbound servers
   ```

3. **Test Inbound:**
   - Send a test email to `reply+TOKEN@yourdomain.com`
   - Check Postmark dashboard for webhook delivery
   - Check Rails logs for processing

### Option 2: ActionMailbox Ingress (Alternative)

If you prefer to use ActionMailbox's built-in ingress:

1. **Configure ingress in routes:**
   ```ruby
   # config/routes.rb
   mount ActionMailbox::Engine => "/rails/action_mailbox"
   ```

2. **Set up ingress URL:**
   - Postmark webhook: `https://yourdomain.com/rails/action_mailbox/postmark/inbound_emails`
   - Requires `POSTMARK_INBOUND_TOKEN` environment variable

3. **Verify token:**
   - Postmark will send requests with token in headers
   - ActionMailbox verifies token automatically

### DNS Configuration

**For Postmark Inbound:**
```
Type: MX
Name: @ (or yourdomain.com)
Value: inbound.postmarkapp.com
Priority: 10
```

**For Reply-To Domain:**
```
Type: TXT
Name: @ (or yourdomain.com)
Value: (Postmark will provide SPF/DKIM records)
```

## Local Testing Commands

### 1. Environment Setup
```bash
# Create .env file (development only)
cp .env.example .env  # If you have an example file
# Or create manually:
echo "OPENAI_API_KEY=your_key_here" > .env
echo "POSTMARK_API_TOKEN=your_token_here" >> .env
echo "INBOUND_EMAIL_DOMAIN=localhost" >> .env
echo "MAIL_FROM=noreply@localhost" >> .env
echo "MAIL_HOST=localhost" >> .env
```

### 2. Database Setup
```bash
# Create and migrate database
bin/rails db:create
bin/rails db:migrate

# Verify migrations
bin/rails db:migrate:status
```

### 3. Start Services
```bash
# Terminal 1: Web server
bin/server

# Terminal 2: Background jobs (required for scheduling)
bin/jobs
```

### 4. Test Email Sending
```bash
# In Rails console
rails console

# Create a test user
user = User.create!(
  email: "test@example.com",
  password: "password123",
  time_zone: "America/Chicago",
  schedule_frequency: "daily",
  schedule_time: Time.parse("09:00")
)
user.update_column(:onboarding_complete, true)
user.update_next_prompt_at!

# Send a prompt
PromptSender.new(user).send_prompt!

# Check email in /letter_opener (development)
```

### 5. Test Inbound Email
```bash
# Use ActionMailbox Conductor (development only)
# Visit: http://localhost:3000/rails/conductor/action_mailbox/inbound_emails

# Or send test email via Rails console
# (requires mail gem or similar)
```

### 6. Test Scheduled Jobs
```bash
# In Rails console
SendScheduledPromptsJob.perform_now

# Check logs for:
# "SendScheduledPromptsJob completed: X sent, Y skipped, Z errors"
```

### 7. Run Smoke Tests
```bash
# If you have RSpec or Minitest
bundle exec rspec spec/models/user_spec.rb
bundle exec rspec spec/services/prompt_sender_spec.rb

# Or run manually in console
rails console
# Test User model
User.create!(email: "test@test.com", password: "test123")
# Test PromptSender
user = User.first
PromptSender.new(user).send_prompt!
```

## Production Deployment Commands

### Render/Heroku-like Platforms

**1. Set Environment Variables:**
```bash
# In your hosting platform dashboard, set:
SECRET_KEY_BASE=<auto-generated>
DATABASE_URL=<provided>
RAILS_ENV=production
POSTMARK_API_TOKEN=<your_token>
INBOUND_EMAIL_DOMAIN=<your_domain>
MAIL_FROM=<your_email>
MAIL_HOST=<your_domain>
OPENAI_API_KEY=<optional>
ROLLBAR_ACCESS_TOKEN=<optional>
```

**2. Deploy:**
```bash
# Render: Push to connected Git repo
git push origin main

# Heroku: Deploy
git push heroku main
```

**3. Run Migrations:**
```bash
# Render: Auto-runs if configured in render.yaml
# Heroku:
heroku run bin/rails db:migrate
```

**4. Start Workers:**
```bash
# Render: Add Background Worker service running `bin/jobs`
# Heroku: Add worker dyno running `bin/jobs`
# Or set SOLID_QUEUE_IN_PUMA=true to run in-process
```

**5. Verify:**
```bash
# Check logs
# Render: Dashboard → Logs
# Heroku: heroku logs --tail

# Check health
curl https://yourdomain.com/up

# Test email sending
# Use dashboard "Send next email now" button
```

## Post-Deployment Verification

- [ ] Health check endpoint responds: `curl https://yourdomain.com/up`
- [ ] Database connection works
- [ ] Email sending works (send test prompt)
- [ ] Inbound email processing works (reply to test prompt)
- [ ] Scheduled jobs running (check logs for `SendScheduledPromptsJob`)
- [ ] Error logging works (check logs for errors)
- [ ] SSL/HTTPS working (force_ssl enabled)
- [ ] No secrets in logs (verify filtered parameters)

## Monitoring

### Logs
- **Rails logs**: STDOUT (captured by hosting platform)
- **Job logs**: Check for `SendScheduledPromptsJob completed` messages
- **Error logs**: Look for `Rails.logger.error` messages

### Metrics to Watch
- Email delivery rate (Postmark dashboard)
- Job processing rate (Solid Queue dashboard if available)
- Error rate (Rails logs or Rollbar)
- Database connection pool usage
- Response times

### Alerts
- Set up alerts for:
  - High error rate
  - Job failures
  - Email delivery failures
  - Database connection issues

## Troubleshooting

### Emails Not Sending
- Check `POSTMARK_API_TOKEN` is set
- Verify sender email is verified in Postmark
- Check Rails logs for delivery errors
- Test with `PromptMailer.prompt_email(prompt_id).deliver_now` in console

### Inbound Emails Not Processing
- Verify MX records point to Postmark
- Check webhook URL is correct
- Verify `INBOUND_EMAIL_DOMAIN` matches your domain
- Check Rails logs for ActionMailbox processing
- Test with ActionMailbox Conductor (dev only)

### Jobs Not Running
- Verify worker process is running (`bin/jobs`)
- Check `config/recurring.yml` is correct
- Verify Solid Queue is configured
- Check logs for job errors

### Database Issues
- Verify `DATABASE_URL` is correct
- Check connection pool size (`RAILS_MAX_THREADS`)
- Verify migrations ran successfully
- Check for connection timeouts

## Security Notes

- ✅ Secrets filtered from logs (`filter_parameter_logging.rb`)
- ✅ SSL enforced in production (`force_ssl = true`)
- ✅ Parameter filtering enabled
- ✅ No secrets in code (all via ENV)
- ✅ API keys not logged
- ✅ Secure password handling (has_secure_password)

## Support

For issues:
1. Check Rails logs
2. Check Postmark dashboard (email issues)
3. Check database logs (connection issues)
4. Review error reporting (Rollbar if configured)
5. Test locally first before deploying
