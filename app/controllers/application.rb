# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  include AuthenticatedSystem
  include SharedHelper
  include PreferencesHelper
  
  before_filter :create_page_view, :require_activation, :tracker_vars,
                :admin_warning, :set_locale

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => '71a8c82e6d248750397d166001c5e308'

  private

    def set_locale
      session[:locale] = params[:locale] if params[:locale]
      I18n.locale = session[:locale] || I18n.default_locale
    end


    def admin_required
      unless current_person.admin?
        flash[:error] = t('flash.admin_access_required')
        redirect_to home_url
      end
    end
  
    # Create a Scribd-style PageView.
    # See http://www.scribd.com/doc/49575/Scaling-Rails-Presentation
    def create_page_view
      PageView.create(:person_id => session[:person_id],
                      :request_url => request.request_uri,
                      :ip_address => request.remote_ip,
                      :referer => request.env["HTTP_REFERER"],
                      :user_agent => request.env["HTTP_USER_AGENT"])
      if logged_in?
        # last_logged_in_at actually captures site activity, so update it now.
        current_person.last_logged_in_at = Time.now
        current_person.save
      end
    end
  
    def require_activation
      if logged_in?
        unless current_person.active? or current_person.admin?
          redirect_to logout_url
        end
      end
    end
    
    # A tracker to tell us about the activity of Insoshi installs.
    def tracker_vars
      File.open("identifier", "w") do |f|
        f.write UUID.new
      end unless File.exist?("identifier")
      @tracker_id = File.open("identifier").read rescue nil
      @env = ENV['RAILS_ENV']
    end
    
    # Warn the admin if his email address or password is still the default.
    def admin_warning
      default_domain = "example.com"
      default_password = "admin"
      if logged_in? and current_person.admin? 
        if current_person.email =~ /@#{default_domain}$/
          flash[:notice] = t('flash.email_is_default', :warning => t('global.warning'), :default_domain => default_domain, :edit_person => edit_person_path(current_person))
        end
        if current_person.unencrypted_password == default_password
          flash[:error] = t('flash.password_is_default', :warning => t('global.warning'), :edit_person => edit_person_path(current_person))        
        end
      end
    end
end
