class SettingsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(settings_params)
      # Compute next_prompt_at based on frequency and send_times
      @user.update_next_prompt_at!
      redirect_to dashboard_path, notice: "Settings updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:time_zone, :prompt_frequency, :send_times)
  end
end
