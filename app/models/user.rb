class User < ApplicationRecord
  has_secure_password

  has_many :prompts, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :topics, dependent: :destroy
  has_many :email_messages, dependent: :destroy

  # You can get entry_analyses through journal_entries if needed:
  has_many :entry_analyses, through: :journal_entries

  validates :email, presence: true, uniqueness: true
end
