class TopicsController < ApplicationController
  def index
    # Preload journal entry counts to avoid N+1 queries
    @topics = current_user.topics
      .left_outer_joins(:entry_topics)
      .select("topics.*, COUNT(entry_topics.id) as journal_entries_count")
      .group("topics.id")
      .order(:name)
  end

  def show
    @topic = current_user.topics.find(params[:id])
    @journal_entries = current_user.journal_entries
      .joins(:entry_topics)
      .where(entry_topics: { topic_id: @topic.id })
      .includes(:prompt, :entry_analysis)
      .order(created_at: :desc)
  end
end
