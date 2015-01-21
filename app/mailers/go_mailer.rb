class GoMailer < ActionMailer::Base
  # see config/initializers/domain_config.rb
  default :from=>"admin@#{DomainConfig::DomainNames.first}"

  # see app/views/layouts/mailer.html.erb and app/views/layouts/mailer.text.erb
  layout 'mailer'

  def dummy_email(entry)
    # see app/views/go_mailer/dummy_email.html.erb and app/views/go_mailer/dummy_email.text.erb 
    @entry = entry 
    mail(:to => entry.user.email, :subject => 'You logged something!')
  end
end
