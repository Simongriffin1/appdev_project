class SendScheduledPromptsJob < ApplicationJob
  queue_as :default

  def perform
    # Find users with onboarding complete, schedule not paused, and next_prompt_at <= now
    # Check in each user's timezone for accurate scheduling
    users = User.where(onboarding_complete: true)
                .where.not(next_prompt_at: nil)
                .where("next_prompt_at <= ?", Time.current)
    
    # Filter out users with paused schedules (if column exists)
    if User.column_names.include?("schedule_paused")
      users = users.where(schedule_paused: false)
    end

    processed_count = 0
    skipped_count = 0
    error_count = 0

    users.find_each do |user|
      begin
        # Check if prompt should be sent (timezone-aware and idempotency check)
        if should_send_prompt?(user)
          PromptSender.new(user).send_prompt!
          processed_count += 1
          Rails.logger.info "Sent scheduled prompt to user #{user.id} (#{user.email})"
        else
          skipped_count += 1
          Rails.logger.debug "Skipped user #{user.id} (#{user.email}) - already sent in this window"
        end
      rescue StandardError => e
        error_count += 1
        # Log error with full context but don't crash the job
        Rails.logger.error "Failed to send prompt to user #{user.id} (#{user.email}): #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
        # Continue with other users even if one fails
      end
    end

    Rails.logger.info "SendScheduledPromptsJob completed: #{processed_count} sent, #{skipped_count} skipped, #{error_count} errors"
  end

  private

  def should_send_prompt?(user)
    return false unless user.onboarding_complete?
    return false unless user.next_prompt_at.present?
    return false if user.schedule_paused? # Don't send if schedule is paused

    # Check in user's timezone
    tz = ActiveSupport::TimeZone[user.time_zone] || ActiveSupport::TimeZone["UTC"]
    now_in_tz = Time.current.in_time_zone(tz)
    next_prompt_in_tz = user.next_prompt_at.in_time_zone(tz)

    # Check if it's time to send (within a 15-minute window)
    return false unless next_prompt_in_tz <= now_in_tz + 15.minutes

    # Idempotency: Check if a prompt was already sent in this scheduled window
    # A "window" is defined as the scheduled time ± 1 hour
    return false if prompt_already_sent_in_window?(user, next_prompt_in_tz)

    true
  end

  def prompt_already_sent_in_window?(user, scheduled_time)
    return false unless user.respond_to?(:last_prompt_sent_at) && user.last_prompt_sent_at.present?

    # Define window as scheduled time ± 1 hour
    window_start = scheduled_time - 1.hour
    window_end = scheduled_time + 1.hour

    # Check if last_prompt_sent_at is within this window
    last_sent_in_tz = user.last_prompt_sent_at.in_time_zone(scheduled_time.time_zone)
    
    last_sent_in_tz >= window_start && last_sent_in_tz <= window_end
  end
end
