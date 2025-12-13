class ApplicationMailbox < ActionMailbox::Base
  # Route inbound replies like: reply+TOKEN@your-domain
  routing(/^reply\+[^@]+@/i => :journal_reply)
end
