# == Schema Information
#
# Table name: prompts
#
#  id               :bigint           not null, primary key
#  body             :text
#  question_1       :text
#  question_2       :text
#  sent_at          :datetime
#  source           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  parent_prompt_id :integer
#  user_id          :bigint           not null
#
# Indexes
#
#  index_prompts_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Prompt < ApplicationRecord
  belongs_to :user, optional: true

  belongs_to :parent_prompt,
             class_name: "Prompt",
             foreign_key: "parent_prompt_id",
             optional: true

  has_many :child_prompts,
           class_name: "Prompt",
           foreign_key: "parent_prompt_id",
           dependent: :nullify

  has_many :journal_entries, dependent: :nullify
  has_many :email_messages, dependent: :nullify

  # Enums
  enum status: {
    draft: "draft",
    sent: "sent",
    replied: "replied"
  }

  enum prompt_type: {
    daily: "daily",
    weekly: "weekly",
    adhoc: "adhoc"
  }

  # Validations
  validates :idempotency_key, uniqueness: { scope: :user_id }, allow_nil: true
  validates :status, presence: true

  # Callbacks
  before_validation :set_default_status, on: :create
  before_validation :generate_idempotency_key, on: :create, if: -> { idempotency_key.blank? }
  after_update :update_status_on_reply, if: -> { saved_change_to_replied_at? }

  # Status transitions
  def mark_as_sent!
    return if sent?
    update!(status: :sent, sent_at: Time.current)
  end

  def mark_as_replied!
    return if replied?
    update!(status: :replied, replied_at: Time.current)
  end

  private

  def set_default_status
    self.status ||= :draft
  end

  def generate_idempotency_key
    # Generate based on user_id and timestamp
    timestamp = sent_at || created_at || Time.current
    self.idempotency_key = Digest::MD5.hexdigest("#{user_id}-#{timestamp.to_i}")
  end

  def update_status_on_reply
    mark_as_replied! if replied_at.present? && !replied?
  end
end
