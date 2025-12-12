class EntryTopicsController < ApplicationController
  # EntryTopics are created programmatically via EntryAnalysisGenerator
  # This controller is not exposed in routes and exists only to clean up broken draft code
  before_action :authenticate_user!

  # Note: EntryTopics are not directly exposed in the UI
  # They are accessed through journal_entries -> topics association
end
