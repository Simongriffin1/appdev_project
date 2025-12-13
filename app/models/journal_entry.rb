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

  validates :body, presence: true

  before_validation :set_default_source

  private

  def set_default_source
    self.source ||= "email"
  end
end
