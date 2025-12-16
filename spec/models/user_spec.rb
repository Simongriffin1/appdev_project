# Smoke tests for User model
# Run with: bundle exec rspec spec/models/user_spec.rb

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "requires email" do
      user = User.new(password: "password123")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it "requires unique email" do
      User.create!(email: "test@example.com", password: "password123")
      duplicate = User.new(email: "test@example.com", password: "password123")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to be_present
    end
  end

  describe "#onboarding_complete?" do
    it "returns false when time_zone is missing" do
      user = User.new(email: "test@example.com", password: "password123")
      expect(user.onboarding_complete?).to be false
    end

    it "returns true when all required fields are present" do
      user = User.new(
        email: "test@example.com",
        password: "password123",
        time_zone: "America/Chicago",
        schedule_frequency: "daily",
        schedule_time: Time.parse("09:00")
      )
      expect(user.onboarding_complete?).to be true
    end
  end

  describe "#update_next_prompt_at!" do
    it "calculates next prompt time for daily frequency" do
      user = User.create!(
        email: "test@example.com",
        password: "password123",
        time_zone: "America/Chicago",
        schedule_frequency: "daily",
        schedule_time: Time.parse("09:00")
      )
      
      user.update_next_prompt_at!
      expect(user.next_prompt_at).to be_present
      expect(user.next_prompt_at).to be > Time.current
    end
  end
end
