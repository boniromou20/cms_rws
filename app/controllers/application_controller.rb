class ApplicationController < ActionController::Base
  protect_from_forgery
  before_filter :check_session_expiration, :authenticate_user!, :update_user_location

  layout false

  include Pundit
  include Rigi::PunditHelper::Controller
  include CageInfoHelper
  include HomeHelper

  rescue_from Exception, :with => :handle_fatal_error
  rescue_from Pundit::NotAuthorizedError, :with => :handle_unauthorize

  def client_ip
    if Rails.env.development?
      request.remote_ip
    else
      request.env["HTTP_X_FORWARDED_FOR"]
    end
  end

  def handle_route_not_found
    respond_to do |format|
      format.html { render partial: "shared/error404", formats: [:html], layout: "error_page", :status => :not_found }
      format.js { render partial: "shared/error404", formats: [:js], :status => :not_found }
    end
  end

  def wallet_requester
    requester_factory.get_wallet_requester
  end

  def patron_requester
    requester_factory.get_patron_requester
  end

  def station_requester
    requester_factory.get_station_requester
  end

  def marketing_requester
    requester_factory.get_marketing_requester
  end

  def marketing_wallet_requester
    requester_factory.get_marketing_wallet_requester
  end

  def write_cookie(name, value, domain = :all)
    cookies[name] = {
      value: value,
      domain: domain
    }
  end

  def clear_authorize_info
    cookies.delete(:second_auth_info, domain: :all)
    cookies.delete(:second_auth_result, domain: :all)
  end

  protected

  def check_session_expiration
    if session[:accessed_at] && Time.now.utc - session[:accessed_at] > config_helper.session_expiration_time
      reset_session
    else
      session[:accessed_at] = Time.now.utc
    end
  end

  def update_user_location
    if current_user
      if have_active_location?
        current_user.set_have_active_location(true)
      else
        current_user.set_have_active_location(false)
      end
    end
  end

  def have_active_location?
    session[:machine_token] == cookies[:machine_token] && cookies[:machine_token] != nil
  end

  def sid
    request.session_options[:id]
  end

  def current_shift
    Shift.current(current_casino_id)
  end

  def current_accounting_date
    AccountingDate.current(current_casino_id)
  end

  def current_accounting_date_by_casino_id(casino_id)
    AccountingDate.current(casino_id)
  end

  def current_machine_token
    session[:machine_token]
  end

  def current_casino_id
    user_casino_id = current_user.casino_id if current_user
    machine_info = Machine.parse_machine_token(cookies[:machine_token])
    machine_casino_id = machine_info[:casino_id] if machine_info
    machine_casino_id || user_casino_id
  end

  def current_licensee_id
    Casino.get_licensee_id_by_casino_id(current_casino_id)
  end
  
  def current_licensee_time_zone
    @time_zone ||= Licensee.find_by_id(current_licensee_id).time_zone
  end

  def config_helper
    @config_helper = ConfigHelper.new(current_casino_id) unless @config_helper
    @config_helper
  end

  def requester_factory
    if !@requester_factory || @requester_factory.casino_id != current_casino_id
      @requester_factory = Requester::RequesterFactory.new(REQUESTER_CONFIG_FILE, Rails.env, current_casino_id, current_licensee_id, nil)
    end
    @requester_factory
  end

  def requester_helper
    if !@requester_helper && current_casino_id
      @requester_helper = RequesterHelper.new(requester_factory)
    end
    @requester_helper
  end

  def handle_unauthorize
    Rails.logger.info 'handle_unauthorize'
    flash[:fail] = "flash_message.not_authorize"
    respond_to do |format|
      format.html { render "home/index", formats: [:html] }
      format.js { render "home/unauthorized", formats: [:js] }
    end
  end

  def handle_fatal_error(e)
    @from = params[:from]
    Rails.logger.error "Error message: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.inspect}"
    puts e.backtrace
    puts e.message
    respond_to do |format|
      format.html { render partial: "shared/error500", formats: [:html], layout: "error_page", :status => :internal_server_error }
      format.js { render partial: "shared/error500", formats: [:js], :status => :internal_server_error }
    end
    return
  end

  def get_location_info
    return session[:location_info] if session[:location_info]
    '---'
  end
  def get_casino_info
    return session[:casino_info] if session[:casino_info]
    '---'
  end
end
