class EntryAnalysesController < ApplicationController
  before_action :set_entry_analysis, only: %i[show]

  # GET /entry_analyses
  # Mainly for debugging / curiosity: list analyses for current_user.
  def index
    @entry_analyses = EntryAnalysis
      .joins(:journal_entry)
      .where(journal_entries: { user_id: current_user.id })
      .order(created_at: :desc)
  end

  # GET /entry_analyses/:id
  def show
  end

  private

  def set_entry_analysis
    @entry_analysis = EntryAnalysis
      .joins(:journal_entry)
      .where(journal_entries: { user_id: current_user.id })
      .find(params[:id])
  end
end
