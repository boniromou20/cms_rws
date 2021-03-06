module TransactionQueries
  def self.included(base)
    base.instance_eval do
      scope :since, -> start_time { where("created_at >= ?", start_time) if start_time.present? }
      scope :until, -> end_time { where("created_at <= ?", end_time) if end_time.present? }
      scope :by_player_id, -> player_id { where("player_id = ?", player_id) if player_id.present? }
      scope :by_transaction_id, -> transaction_id { where("id = ?", transaction_id) if transaction_id.present? }
      scope :by_shift_id, -> shift_id { where( "shift_id = ? ", shift_id) if shift_id.present? }
      scope :by_user_id, -> user_id { where( "user_id = ?", user_id) if user_id.present? }
      scope :by_transaction_type_id, -> trans_types { where(:transaction_type_id => trans_types) if trans_types.present?}
      scope :from_shift_id, -> shift_id { where( "shift_id >= ? ", shift_id) if shift_id.present? }
      scope :to_shift_id, -> shift_id { where( "shift_id <= ? ", shift_id) if shift_id.present? }
      scope :in_shift_id, -> shift_id { where( "shift_id in (?) ", shift_id) if shift_id.present? }
      scope :by_slip_number, -> slip_number { where("slip_number = ?", slip_number) if slip_number.present? }
      scope :by_status, -> status { where( :status => status) if status.present? }
      scope :by_casino_id, -> casino_id { where("casino_id = ?", casino_id) if casino_id.present? }
    end

    base.extend ClassMethods
  end

  module ClassMethods
    TRANSACTION_TYPE_ID_LIST = {:deposit => 1, :withdraw => 2, :void_deposit => 3, :void_withdraw => 4, :credit_deposit => 5, :credit_expire => 6, :manual_deposit => 8, :manual_withdraw => 9}

    def only_deposit_withdraw
      by_transaction_type_id([TRANSACTION_TYPE_ID_LIST[:deposit], TRANSACTION_TYPE_ID_LIST[:withdraw]]).by_status(['completed', 'pending'])
    end

    def only_credit_deposit_expire
      by_transaction_type_id([TRANSACTION_TYPE_ID_LIST[:credit_deposit], TRANSACTION_TYPE_ID_LIST[:credit_expire]]).by_status(['completed', 'pending'])
    end
    
    def only_deposit_withdraw_with_exception
      by_transaction_type_id([TRANSACTION_TYPE_ID_LIST[:deposit], TRANSACTION_TYPE_ID_LIST[:withdraw], TRANSACTION_TYPE_ID_LIST[:manual_deposit],TRANSACTION_TYPE_ID_LIST[:manual_withdraw]]).by_status(['completed', 'rejected'])
    end
  
    def search_query_by_player(id_type, id_number, start_shift_id, end_shift_id, operation, licensee_id)
      start_date = AccountingDate.find_by_id(Shift.find_by_id(start_shift_id).accounting_date_id).created_at.change(min: 0)
      end_date = AccountingDate.find_by_id(Shift.find_by_id(end_shift_id).accounting_date_id).created_at.change(min: 0) + 1.days
      if id_number.empty?
        player_id = nil
      else
        player_id = 0
        player = Player.find_by_id_type_and_id_number(id_type.to_sym, id_number, licensee_id)
        player_id = player.id unless player.nil?
      end
      if operation == 'cash'
        #by_player_id(player_id).from_shift_id(start_shift_id).to_shift_id(end_shift_id).only_deposit_withdraw_with_exception
        by_player_id(player_id).where('trans_date >= ? AND trans_date < ? AND shift_id IS NOT ?', start_date, end_date, nil).only_deposit_withdraw_with_exception
      else
        #by_player_id(player_id).from_shift_id(start_shift_id).to_shift_id(end_shift_id).only_credit_deposit_expire
        by_player_id(player_id).where('trans_date >= ? AND trans_date < ?', start_date, end_date).only_credit_deposit_expire
      end
    end

    def daily_transaction_amount_by_player(player, accounting_date, trans_type, casino_id)
	  if player.status == 'not_activate'
	    return 0
	  end
      start_shift_id = accounting_date.shifts.where(:casino_id => casino_id).first.id
      end_shift_id = accounting_date.shifts.where(:casino_id => casino_id).last.id
      start_time = accounting_date.shifts.where(:casino_id => casino_id).first.created_at.change(min: 0)
      
      trans_amt = select('sum(amount) as amount').by_player_id(player.id).by_casino_id(casino_id).by_status('completed').where('trans_date >= ? AND trans_date < ?', start_time, start_time + 1.days).by_transaction_type_id(TRANSACTION_TYPE_ID_LIST[trans_type]).first.amount || 0
     
      today_ref_trans_id = select('ref_trans_id').by_player_id(player.id).by_casino_id(casino_id).by_status('completed').where('trans_date >= ? AND trans_date < ?', start_time, start_time + 1.days).by_transaction_type_id(TRANSACTION_TYPE_ID_LIST[trans_type])
      
      void_amt = select('sum(amount) as amount').by_player_id(player.id).by_casino_id(casino_id).by_status('completed').where('trans_date >= ? AND trans_date < ?', start_time, start_time + 1.days).by_transaction_type_id(TRANSACTION_TYPE_ID_LIST["void_#{trans_type}".gsub('manual_','').to_sym]).where("ref_trans_id in (?)", today_ref_trans_id.map {|i| i.ref_trans_id }).first.amount || 0

      trans_amt - void_amt
    end
  end
  
end
