class FollowUpQuestionJob < ApplicationJob
  queue_as :default

  def perform(journal_entry_id)
    journal_entry = JournalEntry.find_by(id: journal_entry_id)
    return unless journal_entry

    begin
      # Ensure analysis exists before checking for follow-up
      unless journal_entry.entry_analysis.present?
        EntryAnalysisGenerator.new(journal_entry).generate!
        journal_entry.reload
      end
    rescue StandardError => e
      # Log error but don't crash - analysis generation has fallbacks
      Rails.logger.error "EntryAnalysisGenerator error for entry #{journal_entry_id}: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      # Continue - follow-up generator can work without analysis
    end

    begin
      # Generate and send follow-up if appropriate
      FollowUpQuestionGenerator.new(journal_entry).generate_and_send!
    rescue StandardError => e
      # Log error but don't crash the job
      Rails.logger.error "FollowUpQuestionGenerator error for entry #{journal_entry_id}: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      # Job completes successfully even if follow-up fails
    end
  end
end
