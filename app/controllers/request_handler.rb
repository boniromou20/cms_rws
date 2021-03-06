require 'singleton'
class RequestHandler
  include Singleton

  def update(inbound)
    @inbound = inbound
    @inbound[:casino_id] ||= Property.get_casino_id_by_property_id(@inbound[:property_id])
    @inbound[:licensee_id] ||= Property.get_licensee_id_by_property_id(@inbound[:property_id])
    begin
      event_name = inbound[:_event_name].to_sym
      @outbound = self.__send__("process_#{event_name}_event") || {}
    rescue Request::RequestError => e
      @outbound = e.to_hash
    rescue Exception => e
      puts e.backtrace
      puts e.message
      return {:status => 500, :error_code => 'internal error', :error_msg => e.message}
    end
    if @outbound[:error_code].nil?
      @outbound.merge!({:status=>200, :error_code=>'OK', :error_msg=>'Request is carried out successfully.'})
    end
    @outbound
  end

  def get_requester_helper(casino_id)
    requester_config_file = "#{Rails.root}/config/requester_config.yml"
    licensee_id = Casino.get_licensee_id_by_casino_id(casino_id)
    requester_facotry = Requester::RequesterFactory.new(requester_config_file, Rails.env, casino_id, licensee_id, nil)
    RequesterHelper.new(requester_facotry)
  end


  def process_validate_token_event
    Token.validate(@inbound[:login_name], @inbound[:session_token], @inbound[:licensee_id])
    {}
  end

  def process_get_player_info_event
    id_type = @inbound[:id_type]
    id_value = @inbound[:id_value]
    licensee_id = @inbound[:licensee_id]
    casino_id = Casino.get_find_first_casino_id_by_licensee_id(licensee_id)
    get_requester_helper(casino_id).get_player_info(id_type, id_value, licensee_id)
  end

  def process_retrieve_player_info_event
    machine_type = @inbound[:machine_type]
    credential = @inbound[:credential]
    machine_token = @inbound[:machine_token]
    pin = @inbound[:pin]
    casino_id = @inbound[:casino_id]
    get_requester_helper(casino_id).retrieve_info(credential, machine_type, machine_token, pin, casino_id)
  end

  def process_keep_alive_event
    Token.keep_alive(@inbound[:login_name], @inbound[:session_token], @inbound[:casino_id], @inbound[:licensee_id])
    {}
  end

  def process_discard_token_event
    Token.discard(@inbound[:login_name], @inbound[:session_token], @inbound[:licensee_id])
    {}
  end

  def process_get_player_currency_event
    licensee_id = @inbound[:licensee_id]
    login_name = @inbound[:login_name]
    ApiHelper.get_currency(login_name, licensee_id)
  end

  def process_lock_player_event
    licensee_id = @inbound[:licensee_id]
    casino_id = @inbound[:casino_id]
    login_name = @inbound[:login_name]
    ApiHelper.lock_player(login_name, licensee_id, casino_id)
  end

  def process_internal_lock_player_event
    licensee_id = @inbound[:licensee_id]
    login_name = @inbound[:login_name]
    lock_type = @inbound[:lock_type]
    ApiHelper.internal_lock_player(login_name, licensee_id, lock_type)
  end

  def process_internal_unlock_player_event
    licensee_id = @inbound[:licensee_id]
    login_name = @inbound[:login_name]
    lock_type = @inbound[:lock_type]
    ApiHelper.internal_unlock_player(login_name, licensee_id, lock_type)
  end

  def process_validate_machine_token_event
    machine_type = @inbound[:machine_type]
    property_id = @inbound[:property_id]
    casino_id = @inbound[:casino_id]
    machine_token = @inbound[:machine_token]
    response = get_requester_helper(casino_id).validate_machine(machine_type, machine_token, property_id, casino_id)
    response.result_hash
  end

  def process_is_test_mode_player_event
    login_name = @inbound[:login_name]
    session_token = @inbound[:session_token]
    licensee_id = @inbound[:licensee_id]
    ApiHelper.is_test_mode_player(login_name, session_token, licensee_id)
  end

  def process_kiosk_login_event
    card_id = @inbound[:card_id]
    pin = @inbound[:pin]
    casino_id = @inbound[:casino_id]
    get_requester_helper(casino_id).kiosk_login(card_id, pin, casino_id)
  end

  def process_validate_deposit_event
    login_name = @inbound[:login_name]
    ref_trans_id = @inbound[:ref_trans_id]
    amount = @inbound[:amt]
    kiosk_id = @inbound[:kiosk_id]
    session_token = @inbound[:session_token]
    source_type = @inbound[:source_type]
    casino_id = @inbound[:casino_id]
    get_requester_helper(casino_id).validate_deposit(login_name, ref_trans_id, amount, kiosk_id, session_token, source_type, casino_id)
  end

  def process_deposit_event
    login_name = @inbound[:login_name]
    ref_trans_id = @inbound[:ref_trans_id]
    kiosk_id = @inbound[:kiosk_id]
    session_token = @inbound[:session_token]
    casino_id = @inbound[:casino_id]
    get_requester_helper(casino_id).deposit(login_name, ref_trans_id, session_token, casino_id)
  end

  def process_withdraw_event
    login_name = @inbound[:login_name]
    ref_trans_id = @inbound[:ref_trans_id]
    amount = @inbound[:amt]
    kiosk_id = @inbound[:kiosk_id]
    session_token = @inbound[:session_token]
    source_type = @inbound[:source_type]
    casino_id = @inbound[:casino_id]
    get_requester_helper(casino_id).withdraw(login_name, ref_trans_id, amount, kiosk_id, session_token, source_type, casino_id)
  end

  def process_internal_deposit_event
    login_name = @inbound[:login_name]
    amount = @inbound[:amt]
    ref_trans_id = @inbound[:ref_trans_id]
    source_type = @inbound[:source_type]
    casino_id = @inbound[:casino_id]
    promotion_code = @inbound[:promotion_code]
    executed_by = @inbound[:executed_by]
    promotion_info = handle_promotion_info(@inbound)
    get_requester_helper(casino_id).internal_deposit(login_name, amount, ref_trans_id, source_type, casino_id, promotion_code, executed_by, promotion_info)
  end
   
  def process_exception_deposit_event
    login_name = @inbound[:login_name]
    amount = @inbound[:amount]
    ref_trans_id = @inbound[:ref_trans_id]
    source_type = @inbound[:source_type]
    casino_id = @inbound[:casino_id]
    executed_by = @inbound[:executed_by]
    get_requester_helper(casino_id).exception_deposit(login_name, amount, ref_trans_id, source_type, casino_id, executed_by)
  end

  def process_exception_withdraw_event
    login_name = @inbound[:login_name]
    amount = @inbound[:amount]
    ref_trans_id = @inbound[:ref_trans_id]
    source_type = @inbound[:source_type]
    casino_id = @inbound[:casino_id]
    executed_by = @inbound[:executed_by]
    get_requester_helper(casino_id).exception_withdraw(login_name, amount, ref_trans_id, source_type, casino_id, executed_by)
  end
  def handle_promotion_info(ib)
    Hood::ParamUtil.ensure_params_given(ib, :promotion_type, :amt)
    promotion_info = {}
    ib[:amt] = ib[:amt].to_f

    case ib[:promotion_type]
    when "mass_top_up"
      promotion_info[:award_condition] = "Top Up Amount = #{ib[:amt]}"
      promotion_info[:occurrences] = 1
    when "initial_amount"
      promotion_info[:award_condition] = "First Login"
      promotion_info[:occurrences] = 1
    when "daily_rounds_award"
      Hood::ParamUtil.ensure_params_given(ib, :threshold, :max, :each_award, :count)
      Hood::ParamUtil.to_i(ib, :threshold, :max, :count)
      ib[:each_award] = ib[:each_award].to_f
      promotion_info[:award_condition] = "Threshold = #{ib[:threshold]} round#{(ib[:threshold] > 1 )? 's' : '' }, Max = #{ib[:max]}, Each Award = #{ib[:each_award]}"
      promotion_info[:occurrences] = ib[:count]
    when "daily_login_award"
      Hood::ParamUtil.ensure_params_given(ib, :threshold, :max, :each_award, :count)
      Hood::ParamUtil.to_i(ib, :threshold, :max, :count)
      ib[:each_award] = ib[:each_award].to_f
      promotion_info[:award_condition] = "Threshold = #{ib[:threshold]} login#{(ib[:threshold] > 1 )? 's' : '' }, Max = #{ib[:max]}, Each Award = #{ib[:each_award]}"
      promotion_info[:occurrences] = ib[:count]
    when "daily_top_off"
      Hood::ParamUtil.ensure_params_given(ib, :top_off_amt)
      ib[:top_off_amt] = ib[:top_off_amt].to_f
      promotion_info[:award_condition] = "if Account Balance < #{ib[:top_off_amt]}, top off to #{ib[:top_off_amt]}"
      promotion_info[:occurrences] = ib[:top_off_amt] - ib[:amt]
    else
      raise BadRequest("Promotion Type Not Exist")
    end

    promotion_info[:promotion_type] = ib[:promotion_type].split('_').map{|w| w.camelize}.join(' ')
    promotion_info
  end
end
