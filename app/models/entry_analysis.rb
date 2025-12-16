# == Schema Information
#
# Table name: entry_analyses
#
#  id               :bigint           not null, primary key
#  emotion          :string
#  keywords         :text
#  sentiment        :string
#  summary          :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  journal_entry_id :bigint           not null
#
# Indexes
#
#  index_entry_analyses_on_journal_entry_id  (journal_entry_id)
#
# Foreign Keys
#
#  fk_rails_...  (journal_entry_id => journal_entries.id)
#
class EntryAnalysis < ApplicationRecord
  belongs_to :journal_entry

  # If you want an easy shortcut to user:
  has_one :user, through: :journal_entry

  # Validations
  validates :sentiment, inclusion: { in: %w[positive neutral negative] }, allow_nil: true

  # Serialize JSON fields (Rails 8 handles jsonb automatically, but we can add helpers)
  def tags
    super || []
  end

  def tags=(value)
    super(Array(value))
  end

  def key_themes
    super || []
  end

  def key_themes=(value)
    super(Array(value))
  end

  # Helper methods for backward compatibility with keywords
  def keywords
    tags.join(", ")
  end

  def keywords=(value)
    self.tags = value.to_s.split(",").map(&:strip).reject(&:blank?)
  end
end
