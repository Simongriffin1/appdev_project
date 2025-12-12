class TopicsController < ApplicationController
  def index
    @topics = current_user.topics.order(:name)
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
