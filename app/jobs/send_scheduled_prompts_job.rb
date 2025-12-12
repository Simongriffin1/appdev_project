class SendScheduledPromptsJob < ApplicationJob
  queue_as :default

  def perform
    # Find users whose next_prompt_at is now or in the past
    users = User.where("next_prompt_at <= ?", Time.current)
                .where.not(next_prompt_at: nil)
                .where.not(prompt_frequency: nil)
                .where.not(send_times: nil)

    users.find_each do |user|
      begin
        PromptSender.new(user).send_prompt!
      rescue StandardError => e
        Rails.logger.error "Failed to send prompt to user #{user.id}: #{e.message}"
        # Continue with other users even if one fails
      end
    end
  end
end
