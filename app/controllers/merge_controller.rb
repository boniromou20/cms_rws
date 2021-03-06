class MergeController < ApplicationController
  include SearchHelper
  include FundHelper

  rescue_from Merge::InvalidMachineToken, :with => :handle_invalid_machine_token
  rescue_from Merge::AmountInvalidError, :with => :handle_amount_invalid_error
  rescue_from Merge::PendingTransaction, :with => :handle_pending_transaction
 
  def new
    super
    @casino_id = current_casino_id
    @remain_limit = @player.remain_trans_amount(:deposit, @casino_id)
    @fund_type = @player.get_fund_type
    @payment_method = @player.payment_method_types
  end

  def merge_player
    sur_member_id = params[:player][:sur_member_id]
    vic_member_id = params[:player][:vic_member_id]
    @player_sur = policy_scope(Player).find_by_member_id(sur_member_id)
    @player_vic = policy_scope(Player).find_by_member_id(vic_member_id)
    @amount = params[:player_transaction][:sur_amount]
    @amount2 = params[:player_transaction][:vic_amount]
    validate_amount(@amount2)
    @check_transaction_player = PlayerTransaction.find_by_player_id_and_status(@player_sur.id, 'pending')
    @check_transaction_player2 = PlayerTransaction.find_by_player_id_and_status(@player_vic.id, 'pending')
    raise Merge::PendingTransaction if (@check_transaction_player or @check_transaction_player2)
    
    @server_amount = to_server_amount(@amount2)
    @ref_trans_id = nil
    @payment_method_type = params[:payment_method_type]
    @source_of_funds = params[:source_of_funds]

    execute_transaction

    @player_vic.lock_account!('cage_lock')
    flash[:success] = {key: "flash_message.merge_complete", replace: {vic_player: @player_vic.member_id, sur_player: @player_sur.member_id}}
    redirect_to players_search_merge_path(operation: :merge)
  end

  def validate_amount(amount)
    raise Merge::AmountInvalidError.new "Input amount not valid" unless amount.is_a?(String) && to_server_amount( amount ) > 0
  end

  def to_server_amount( amount )
    (amount.to_f * 100).round(2).to_i
  end

  def execute_transaction
    AuditLog.player_log('deposit', current_user.name, client_ip, sid,:description => {:location => get_location_info, :shift => current_shift.name}) do
      @data = {:remark => ""}
      @data[:deposit_remark] = "Fund transfer from account #{@player_vic.member_id}"
      @transaction = create_deposit_transaction(@player_sur.member_id, @server_amount, @ref_trans_id, @data.to_yaml)
    end
    AuditLog.player_log('withdraw', current_user.name, client_ip, sid,:description => {:location => get_location_info, :shift => current_shift.name}) do
      @data = {:remark => ""}
      @data[:withdraw_remark] = "Fund transfer to account #{@player_sur.member_id}"
      @transaction2 = create_withdraw_transaction(@player_vic.member_id, @server_amount, @ref_trans_id, @data.to_yaml)
    end
    puts Approval::Request::PENDING
    response = Approval::Models.submit('player', @player_vic.id, 'merge_player', get_submit_data, @current_user.name)

  end

  def create_deposit_transaction(member_id, amount, ref_trans_id = nil, data)
    raise Merge::InvalidMachineToken unless current_machine_token
    PlayerTransaction.send "save_deposit_transaction", member_id, amount, current_shift.id, current_user.id, current_machine_token, ref_trans_id, data
  end

  def create_withdraw_transaction(member_id, amount, ref_trans_id = nil, data)
    raise Merge::InvalidMachineToken unless current_machine_token
    PlayerTransaction.send "save_withdraw_transaction", member_id, amount, current_shift.id, current_user.id, current_machine_token, ref_trans_id, data
  end

  def get_submit_data
    {
      :licensee_id => Licensee.find_by_id(@player_sur.licensee_id).name,
      :player_vic_id => @player_vic.member_id,
      :player_vic_before_amount => '%.2f'% @amount2,
      :minus_amount => '%.2f'% @amount2,
      :player_vic_after_amount => 0,
      :player_sur_id => @player_sur.member_id,
      :player_sur_before_amount => '%.2f'% @amount,
      :amount => '%.2f'% @amount2,
      :player_sur_after_amount => '%.2f'% ((@amount.to_f + @amount2.to_f).round(3)),
      :transaction => [@transaction.id, @transaction2.id]
    }
  end

  def call_wallet(member_id, amount, ref_trans_id, trans_date, source_type, machine_token)
    wallet_requester.deposit(member_id, amount, ref_trans_id, trans_date, source_type, current_user.uid, current_user.name, machine_token)
  end

  def extract_params
    super
    @deposit_reason = "#{params[:player_transaction][:deposit_reason]}"
    if @deposit_reason != ""
      @data[:deposit_remark] = @deposit_reason
    end
  end

  def search
    @operation = params[:operation]
    @card_id = params[:card_id]
  end

  def handle_invalid_machine_token(e)
    handle_fund_error('void_transaction.invalid_machine_token')
  end

  def handle_amount_invalid_error(e)
    handle_fund_error("invalid_amt.merge")
  end
 
  def handle_pending_transaction(e)
    handle_fund_error("search_error.pending_transaction")
  end

  def handle_fund_error(msg)
    flash[:fail] = msg
    redirect_to players_search_merge_path + "?operation=merge"
  end
end

