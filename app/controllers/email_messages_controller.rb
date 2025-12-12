class EmailMessagesController < ApplicationController
  before_action :set_email_message, only: [:show]

  # GET /email_messages
  def index
    @email_messages = current_user.email_messages.order(sent_or_received_at: :desc)
  end

  # GET /email_messages/:id
  def show
  end

  private

  def set_email_message
    @email_message = current_user.email_messages.find(params[:id])
  end
end
