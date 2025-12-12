class Topic < ApplicationRecord
  belongs_to :user

  has_many :entry_topics, dependent: :destroy
  has_many :journal_entries, through: :entry_topics
end
