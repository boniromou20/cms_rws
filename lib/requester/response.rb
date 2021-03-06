module Requester
  module ResponseHelper
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def define_attr(*args)
        args.each do |attr|
          define_method(attr) do
            if @result_hash.class == Hash
              @result_hash[attr]
            else
              nil
            end
          end
        end
      end
    end
  end

  class Response
    attr_reader :result_hash
    include ResponseHelper
    define_attr :error_code

    def initialize(result_hash)
      @result_hash = result_hash
    end

    def error_msg
      @result_hash[:error_msg].to_s || "no message"
    end

    def exception_msg
      "error_code #{error_code}: #{error_msg}"
    end

    def success?
      ['OK'].include?(error_code)
    end

    def add_balance_methods
      [:balance,:credit_balance,:credit_expired_at].each do |m|
        if !self.respond_to?(m)
          self.define_singleton_method(m) do
            'no_balance'
          end
        end
      end
    end
  end

# wallet
  class WalletResponse < Response
    def invalid_login_name?
      ['InvalidLoginName'].include?(error_code)
    end
  end

  class CreatePlayerResponse < WalletResponse
  end

  class GetPlayerBalanceResponse < WalletResponse
    def balance
      if @result_hash[:balance]
        return @result_hash[:balance].to_f
      else
        return 'no_balance'
      end
    end

    def credit_balance
      if @result_hash[:credit_balance]
        return @result_hash[:credit_balance].to_f
      else
        return 'no_balance'
      end
    end

    def credit_expired_at
      if @result_hash[:credit_expired_at] && credit_balance != 'no_balance' && credit_balance > 0
        return @result_hash[:credit_expired_at].to_time(:local)
      else
        return 'no_balance'
      end
    end
  end

  class GetAccountActivityResponse < WalletResponse
    def total_count
      @result_hash[:total_count] || 0
    end

    def transactions
      @result_hash[:transactions] || []
    end
  end

  class GetPlayerBalancesResponse < WalletResponse
    def players
      @result_hash[:players] || []
    end
  end

  class GetTotalBalancesResponse < WalletResponse
    def player_size
      @result_hash[:player_size] || 0
    end

    def total_balances
      @result_hash[:total_balances] || 0
    end

    def total_credit_balances
      @result_hash[:total_credit_balances] || 0
    end
  end

  class NoAccountActivityResponse < GetAccountActivityResponse
    def initialize
      @result_hash = {:error_code => 'NoRecord'}
    end

    def total_count
      0
    end

    def transactions
      []
    end
  end

  class NoBalanceResponse < GetPlayerBalanceResponse
    def initialize
      @result_hash = {:error_code => 'NoBalance'}
    end
  end

  class WalletTransactionResponse < WalletResponse
    def trans_date
      #@result_hash[:trans_date].to_time(:local)
      Time.parse(@result_hash[:trans_date])
    end

    def success?
      ['OK','AlreadyProcessed'].include?(error_code)
    end

    def amount_not_enough?
      ['AmountNotEnough'].include?(error_code)
    end

    def credit_not_expired?
      ['CreditNotExpired'].include?(error_code)
    end

    def amount_not_match?
      ['AmountNotMatch'].include?(error_code)
    end

    def balance
      # @result_hash[:balance].to_f if @result_hash[:balance]
      # @result_hash[:after_balance].to_f if  @result_hash[:after_balance]
      (@result_hash[:balance] || @result_hash[:after_balance]).to_f
    end
  end

# station
  class StationResponse < Response
    define_attr :property_id, :zone_id, :zone_name, :location_id, :location_name, :machine_id, :machine_name, :uuid, :casino_id
  end

# patron
  class PatronResponse < Response
  end

  class PlayerInfoResponse < PatronResponse
    define_attr :player
  end

  class ValidatePinResponse < PlayerInfoResponse
    def invalid_pin?
      ['InvalidPin'].include?(error_code)
    end
  end

  class PlayerInfosResponse < PatronResponse
    define_attr :players
  end

  class PinAuditLogResponse < PatronResponse
    define_attr :audit_logs

    def invalid_time_range?
      ['InvalidTimeRange'].include?(error_code)
    end
  end
end
