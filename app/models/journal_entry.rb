# == Schema Information
#
# Table name: journal_entries
#
#  id          :bigint           not null, primary key
#  body        :text
#  received_at :datetime
#  source      :string           default("email")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  prompt_id   :bigint
#  user_id     :bigint           not null
#
# Indexes
#
#  index_journal_entries_on_prompt_id  (prompt_id)
#  index_journal_entries_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (prompt_id => prompts.id)
#  fk_rails_...  (user_id => users.id)
#
class JournalEntry < ApplicationRecord
  belongs_to :user
  belongs_to :prompt, optional: true

  has_one :entry_analysis, dependent: :destroy

  has_many :entry_topics, dependent: :destroy
  has_many :topics, through: :entry_topics

  has_many :email_messages, dependent: :nullify

  # Enums
  enum source: {
    email: "email",
    web: "web"
  }

  # Validations
  validates :body, presence: true
  validates :word_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :message_id_hash, uniqueness: true, allow_nil: true

  # Callbacks
  before_validation :set_default_source
  before_save :calculate_word_count
  before_save :update_user_last_entry_at
  after_create :update_prompt_replied_at

  private

  def calculate_word_count
    return if body.blank?
    self.word_count = body.split(/\s+/).length
  end

  def update_user_last_entry_at
    if received_at.present? && (new_record? || saved_change_to_received_at?)
      user.update_column(:last_entry_at, received_at)
    end
  end

  def update_prompt_replied_at
    return unless prompt && received_at.present?
    prompt.update_column(:replied_at, received_at) if prompt.replied_at.nil?
    prompt.mark_as_replied! unless prompt.replied?
  end

  def set_default_source
    self.source ||= :email
  end
end
