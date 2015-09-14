class Player < ActiveRecord::Base
  belongs_to :currency
  include ActionView::Helpers
  include FundHelper
  attr_accessible :card_id, :currency_id,:member_id, :first_name, :status, :last_name
  validates_uniqueness_of :member_id, :card_id

  STATUS_LOCKED = 'locked'
  STATUS_NORMAL = 'active'

  def full_name
    self.first_name + " " + self.last_name
  end

  def balance_str
    to_display_amount_str(balance)
  end

  def account_locked?
    return status == STATUS_LOCKED
  end

  def lock_account!
    self.status = STATUS_LOCKED
    self.save
  end

  def unlock_account!
    self.status = STATUS_NORMAL
    self.save
  end

  class << self
    def instance
      @player = Player.new unless @player
      @player
    end

    def create_by_params(params)
      verify_player_params(params)

      card_id = params[:card_id]
      member_id = params[:member_id]
      first_name = params[:first_name].downcase
      last_name = params[:last_name].downcase

      player = new
      player.card_id = card_id
      player.member_id = member_id
      player.first_name = first_name
      player.last_name = last_name
      player.currency_id = 1
      player.status = STATUS_NORMAL
      begin
        player.save!
      rescue ActiveRecord::RecordInvalid => ex
        duplicated_filed = ex.record.errors.keys.first.to_s
        raise CreatePlayer::DuplicatedFieldError, duplicated_filed
      end
      player
    end

    def update_by_params(params)
      verify_player_params(params)

      card_id = params[:card_id]
      member_id = params[:member_id]
      first_name = params[:first_name].downcase
      last_name = params[:last_name].downcase

      player = find_by_member_id(member_id)
      player.card_id = card_id
      player.first_name = first_name
      player.last_name = last_name
      begin
        player.save!
      rescue
        raise "duplicate"
      end
    end

    def find_by_type_id(id_type, id_number)
      if id_type == "member_id"
        find_by_member_id(id_number)
      else
        find_by_card_id(id_number)
      end
    end

    def retrieve_info(card_id, terminal_id, pin, property_id)
      player = Player.find_by_card_id(card_id)
      return {:status => 400, :error_code => 'InvalidCardId', :error_msg => 'Card id is not exist'} unless player
      return {:status => 400, :error_code => 'PlayerLocked', :error_msg => 'Player is locked'} if player.account_locked?
      login_name = player.member_id
      currency = player.currency.name
      balance = @wallet_requester.get_player_balance(player.member_id)
      #TODO gen a real token
      session_token = 'abm39492i9jd9wjn'
      Token.create_or_update(login_name, session_token, property_id, terminal_id)
      {:login_name => login_name, :currency => currency, :balance => balance, :session_token => session_token}
    end
  end

  protected

  class << self
    def str_is_i?(str)
      !!(str =~ /^[0-9]+$/)
    end

    def verify_player_params(params)
      card_id = params[:card_id]
      member_id = params[:member_id]
      first_name = params[:first_name]
      last_name = params[:last_name]

      raise CreatePlayer::ParamsError, "card_id_length_error" if card_id.nil? || card_id.blank?
      raise CreatePlayer::ParamsError, "member_id_length_error" if member_id.nil? || member_id.blank?
      raise CreatePlayer::ParamsError, "first_name_blank_error" if first_name.nil? || first_name.blank?
      raise CreatePlayer::ParamsError, "last_name_blank_error" if last_name.nil? || last_name.blank?

      raise CreatePlayer::ParamsError, "card_id_only_number_allowed_error" if !str_is_i?(card_id)
      raise CreatePlayer::ParamsError, "member_id_only_number_allowed_error" if !str_is_i?(member_id)
    end
  end
end
