class StreakUpdater
  def self.update_for_user(user)
    new(user).update
  end

  def initialize(user)
    @user = user
  end

  def update
    return unless @user.respond_to?(:streak_count)

    # Calculate current streak
    streak = calculate_streak
    
    # Update streak_count if it changed
    if @user.streak_count != streak
      @user.update_column(:streak_count, streak)
      Rails.logger.info "Updated streak for user #{@user.id}: #{streak} days"
    end
    
    streak
  end

  private

  def calculate_streak
    return 0 if @user.journal_entries.empty?

    # Get entries ordered by date (most recent first)
    entries_by_date = @user.journal_entries
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
end
