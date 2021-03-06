class FrontMoneyController < ApplicationController
  layout 'cage'
  include FormattedTimeHelper
  include FrontMoneyHelper
  before_filter :only => [:search, :do_search] do |controller|
    authorize_action :Shift, :search_fm?
  end

  def search_current_accounting_date_by_casino_id
    result = current_accounting_date_by_casino_id(params[:casino_id]).accounting_date

    respond_to do |format|
      format.json { render :text => result.to_json }
    end
  end

  def search
    @casino_id = current_casino_id
    @accounting_date = params[:accounting_date] || current_accounting_date.accounting_date
  end

  def do_search
    begin
      if (params[:select_casino] and is_date?(params[:accounting_date]) and (Time.parse(params[:accounting_date]) > current_accounting_date_by_casino_id(params[:select_casino]).accounting_date))
        # Select date greater than current accounting date handle
        accounting_date = parse_date(current_accounting_date_by_casino_id(params[:select_casino]).accounting_date.to_s, current_accounting_date.accounting_date)
        @accounting_date = AccountingDate.get_by_date(accounting_date)
        @player_transactions = []
      else
        accounting_date = parse_date(params[:accounting_date], current_accounting_date.accounting_date)
        @accounting_date = AccountingDate.get_by_date(accounting_date)
        start_shift = @accounting_date.shifts.first
        end_shift = @accounting_date.shifts.last
        all_shift = Shift.get_shift_by_date_and_casino(@accounting_date.id, params[:select_casino]) if params[:select_casino]
        raise FrontMoneyHelper::NoResultException.new "shift not found" if start_shift.nil? || end_shift.nil?
        @player_transactions = params[:select_casino] ? PlayerTransaction.search_transactions_by_shift_id(current_user.id, all_shift) : PlayerTransaction.search_transactions_by_user_and_shift(current_user.id, start_shift.id, end_shift.id)
        #@player_transactions = policy_scope(@player_transactions)
      end
    rescue FrontMoneyHelper::NoResultException => e
      @player_transactions = []
    end
    respond_to do |format|
      format.html { render partial: "front_money/search_result", formats: [:html] }
      format.js { render partial: "front_money/search_result", formats: [:js] }
    end
  end


  def is_date?(date)
    begin
      Date.parse(date)
    rescue ArgumentError
      return false
    end
    true
  end
end
