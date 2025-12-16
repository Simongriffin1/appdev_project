class SettingsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user

    # Convert schedule_time string to Time object if provided
    user_params = settings_params.dup
    if user_params[:schedule_time].present? && user_params[:schedule_time].is_a?(String)
      # Parse time string (format: "HH:MM")
      time_parts = user_params[:schedule_time].split(":")
      if time_parts.length >= 2
        hour = time_parts[0].to_i
        min = time_parts[1].to_i
        # Create a Time object (using 2000-01-01 as base date, only time matters)
        user_params[:schedule_time] = Time.zone.parse("2000-01-01 #{hour}:#{min}:00")
      end
    end

    if @user.update(user_params)
      # Compute next_prompt_at based on frequency and schedule_time
      @user.update_next_prompt_at!
      # Ensure onboarding_complete is set after saving settings
      @user.update_column(:onboarding_complete, true) if @user.onboarding_complete?
      redirect_to dashboard_path, notice: "Settings updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:time_zone, :schedule_frequency, :schedule_time, :prompt_frequency, :send_times)
  end
end
