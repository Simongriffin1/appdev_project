class JournalEntry < ApplicationRecord
  belongs_to :user
  belongs_to :prompt, optional: true

  has_one :entry_analysis, dependent: :destroy

  has_many :entry_topics, dependent: :destroy
  has_many :topics, through: :entry_topics

  has_many :email_messages, dependent: :nullify
end
