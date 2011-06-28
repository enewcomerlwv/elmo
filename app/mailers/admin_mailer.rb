class AdminMailer < ActionMailer::Base
  default :from => configatron.site_email
  
  def error(exception, session = nil, params = nil, env = nil)
    @exception = exception
    @session = session
    @params = params
    @env = env
    path = env && env['REQUEST_URI'] && (": " + env['REQUEST_URI']) || ""
    mail(:to => configatron.webmaster_emails, :subject => "Error#{path}")
  end
end
