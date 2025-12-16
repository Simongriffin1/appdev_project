# Smoke tests for PromptSender service
# Run with: bundle exec rspec spec/services/prompt_sender_spec.rb

require "rails_helper"

RSpec.describe PromptSender, type: :service do
  let(:user) do
    User.create!(
      email: "test@example.com",
      password: "password123",
      time_zone: "America/Chicago",
      schedule_frequency: "daily",
      schedule_time: Time.parse("09:00"),
      onboarding_complete: true
    )
  end

  describe "#send_prompt!" do
    it "creates a prompt" do
      expect {
        PromptSender.new(user).send_prompt!
      }.to change { Prompt.count }.by(1)
    end

    it "updates user's last_prompt_sent_at" do
      PromptSender.new(user).send_prompt!
      user.reload
      expect(user.last_prompt_sent_at).to be_present
    end

    it "updates user's next_prompt_at" do
      PromptSender.new(user).send_prompt!
      user.reload
      expect(user.next_prompt_at).to be_present
      expect(user.next_prompt_at).to be > Time.current
    end

    it "creates an EmailMessage record" do
      expect {
        PromptSender.new(user).send_prompt!
      }.to change { EmailMessage.count }.by(1)
    end
  end
end
