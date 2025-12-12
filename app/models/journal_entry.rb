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
    self.source ||= "web"
  end
end
