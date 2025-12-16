# == Schema Information
#
# Table name: users
#
#  id               :bigint           not null, primary key
#  email            :string
#  next_prompt_at   :datetime
#  password_digest  :string
#  prompt_channel   :string
#  prompt_frequency :string
#  send_times       :string
#  time_zone        :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
class User < ApplicationRecord
  has_secure_password

  has_many :prompts, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :topics, dependent: :destroy
  has_many :email_messages, dependent: :destroy

  # You can get entry_analyses through journal_entries if needed:
  has_many :entry_analyses, through: :journal_entries

  # Enums
  enum schedule_frequency: {
    daily: "daily",
    weekdays: "weekdays",
    weekly: "weekly"
  }

  validates :email, presence: true, uniqueness: true
  validates :streak_count, numericality: { greater_than_or_equal_to: 0 }

  before_save :normalize_email
  before_save :update_onboarding_complete

  def onboarding_complete?
    # Use the database column if available, otherwise compute
    if respond_to?(:onboarding_complete) && !onboarding_complete.nil?
      onboarding_complete
    else
      time_zone.present? && (schedule_frequency.present? || prompt_frequency.present?) && (schedule_time.present? || send_times.present?)
    end
  end

  def schedule_paused?
    respond_to?(:schedule_paused) && schedule_paused == true
  end

  def pause_schedule!
    update_column(:schedule_paused, true) if respond_to?(:schedule_paused)
  end

  def resume_schedule!
    return unless respond_to?(:schedule_paused)
    update_column(:schedule_paused, false)
    update_next_prompt_at! # Recalculate next prompt time
  end

  def update_next_prompt_at!
    # Don't update if schedule is paused
    return if schedule_paused?
    
    # Support both old (send_times) and new (schedule_time) formats
    frequency = schedule_frequency || prompt_frequency
    return unless time_zone.present? && frequency.present?

    tz = ActiveSupport::TimeZone[time_zone] || ActiveSupport::TimeZone["America/Chicago"]
    now = Time.current.in_time_zone(tz)

    # Use schedule_time if available, otherwise parse send_times
    if schedule_time.present?
      hour = schedule_time.hour
      min = schedule_time.min
      candidate = now.change(hour: hour, min: min, sec: 0)
      
      # If time has passed today, move forward based on frequency
      if candidate <= now
        case frequency
        when "weekly"
          # Move to next week (same day)
          candidate = candidate + 7.days
        else
          # For daily/weekdays, move to tomorrow
          candidate = candidate + 1.day
        end
      end
      
      next_time = candidate
    elsif send_times.present?
      # Parse send_times (comma-separated local times like "09:00,21:00")
      times = send_times.split(",").map(&:strip).reject(&:blank?)
      return if times.empty?

      # Find the next send time
      next_time = nil
      times.each do |time_str|
        hour, min = time_str.split(":").map(&:to_i)
        candidate = now.change(hour: hour, min: min || 0, sec: 0)
        candidate = candidate + 1.day if candidate <= now
        next_time = candidate if next_time.nil? || candidate < next_time
      end
    else
      return
    end

    # Adjust based on frequency
    case frequency
    when "daily"
      # Use the next_time as is (already adjusted if time passed)
    when "weekdays"
      # Skip weekends
      while next_time.saturday? || next_time.sunday?
        next_time = next_time + 1.day
      end
    when "weekly"
      # For weekly, next_time is already set to next week same day if time passed
      # No additional adjustment needed
    end

    update_column(:next_prompt_at, next_time)
  end

  def current_streak
    # Use database field if available and up-to-date
    if respond_to?(:streak_count) && streak_count.present?
      return streak_count
    end

    # Fallback: calculate from entries
    return 0 if journal_entries.empty?

    # Get entries ordered by date (most recent first)
    entries_by_date = journal_entries
                      .where.not(received_at: nil)
                      .order(received_at: :desc)
                      .group_by { |e| e.received_at.to_date }

    return 0 if entries_by_date.empty?

    # Calculate streak by checking consecutive days
    streak = 0
    current_date = Time.current.to_date

    # Start from today and work backwards
    loop do
      if entries_by_date.key?(current_date)
        streak += 1
        current_date -= 1.day
      else
        # If we have entries but not today, check if yesterday had an entry
        # (allows for same-day streak if entry was made today)
        break if streak == 0
        # If we already have a streak going, allow one day gap
        break if streak > 0 && !entries_by_date.key?(current_date)
        current_date -= 1.day
      end

      # Safety: don't check more than 365 days back
      break if (Time.current.to_date - current_date) > 365
    end

    streak
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip if email.present?
  end

  def update_onboarding_complete
    # Keep onboarding_complete in sync
    self.onboarding_complete = time_zone.present? && (schedule_frequency.present? || prompt_frequency.present?) && (schedule_time.present? || send_times.present?)
  end
end
