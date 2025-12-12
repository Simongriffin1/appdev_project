class User < ApplicationRecord
  has_secure_password

  has_many :prompts, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :topics, dependent: :destroy
  has_many :email_messages, dependent: :destroy

  # You can get entry_analyses through journal_entries if needed:
  has_many :entry_analyses, through: :journal_entries

  validates :email, presence: true, uniqueness: true

  before_save :normalize_email

  def onboarding_complete?
    time_zone.present? && prompt_frequency.present? && send_times.present?
  end

  def update_next_prompt_at!
    return unless time_zone.present? && prompt_frequency.present? && send_times.present?

    tz = ActiveSupport::TimeZone[time_zone] || ActiveSupport::TimeZone["America/Chicago"]
    now = Time.current.in_time_zone(tz)

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

    # Adjust based on frequency
    case prompt_frequency
    when "daily"
      # Use the next_time as is
    when "weekdays"
      # Skip weekends
      while next_time.saturday? || next_time.sunday?
        next_time = next_time + 1.day
      end
    when "weekly"
      # Move to next week (same day of week)
      next_time = next_time + 7.days
    end

    update_column(:next_prompt_at, next_time)
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip if email.present?
  end
end
