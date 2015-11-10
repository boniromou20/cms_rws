require "feature_spec_helper"
require "rails_helper"

describe TokensController do
  def clean_dbs
    Token.delete_all
    PlayersLockType.delete_all
    Player.delete_all    
  end

  before(:all) do
    include Warden::Test::Helpers
    Warden.test_mode!
  end

  after(:all) do
    Warden.test_reset!
  end

  describe '[29] Itegration Service Cage APIs Login' do
    before(:each) do
      clean_dbs
      @player = Player.create!(:first_name => "test", :last_name => "player", :member_id => '123456', :card_id => '1234567890', :currency_id => 1, :status => "active", :property_id => 20000)
      allow_any_instance_of(LaxSupport::AuthorizedRWS::Parser).to receive(:verify).and_return([20000])
      bypass_rescue
    end

    after(:each) do
      clean_dbs
    end

    it '[29.1] Card ID is not exist' do
      allow_any_instance_of(Requester::Station).to receive(:validate_machine_token).and_return({:error_code => 'OK'})
      post 'retrieve_player_info', {:card_id => "1234567891", :machine_token => "1234567891", :pin => "1234"}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'InvalidCardId'
    end

    it '[29.2] Card ID is exist and generate token' do
      mock_token = "afe1f247-5eaa-4c2c-91c7-33a5fb637713"
      allow_any_instance_of(Requester::Station).to receive(:validate_machine_token).and_return({:error_code => 'OK'})
      allow_any_instance_of(Requester::Standard).to receive(:get_player_balance).and_return(100.00)
      allow(SecureRandom).to receive(:uuid).and_return(mock_token)
      post 'retrieve_player_info', {:card_id => "1234567890", :machine_token => "1234567891", :pin => "1234", :property_id => 20000}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'OK'
      expect(result[:error_msg]).to eq 'Request is carried out successfully.'
      expect(result[:session_token]).to eq mock_token
      expect(result[:login_name]).to eq @player.member_id
      expect(result[:currency]).to eq Currency.find(@player.currency_id).name
      expect(result[:balance]).to eq 100.0
    end

    it '[29.3] Player is locked' do
      @player.lock_account!
      allow_any_instance_of(Requester::Station).to receive(:validate_machine_token).and_return({:error_code => 'OK'})
      get 'retrieve_player_info', {:card_id => "1234567890", :machine_token => "1234567891", :pin => "1234", :property_id => 20000}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'PlayerLocked'
    end
  end

  describe '[30] Cage API: Validate Token' do
    before(:each) do
      clean_dbs
      bypass_rescue
      @player = Player.create!(:id => 10, :first_name => "test", :last_name => "player", :member_id => '123456', :card_id => '1234567890', :currency_id => 1, :status => "active", :property_id => 20000)
      @token = Token.create!(:session_token => 'abm39492i9jd9wjn', :player_id => 10, :expired_at => Time.now + 1800)
      allow_any_instance_of(LaxSupport::AuthorizedRWS::Parser).to receive(:verify).and_return([20000])
    end

    after(:each) do
      Token.delete_all
      Player.delete_all
      clean_dbs
    end

    it '[30.1] Validation pass' do
      get 'validate', {:login_name => "123456", :session_token => 'abm39492i9jd9wjn', :property_id => 20000}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'OK'
      expect(result[:error_msg]).to eq 'Request is carried out successfully.'
    end

    it '[30.2] Validation fail with invalid token OK' do
      get 'validate', {:login_name => "123456", :session_token => 'a456456887676esn', :property_id => 20000}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'InvalidSessionToken'
      expect(result[:error_msg]).to eq 'Session token is invalid.'
    end
  end

  describe '[32] Cage API: Discard Token' do
    before(:each) do
      clean_dbs
      bypass_rescue
      @player = Player.create!(:id => 10, :first_name => "test", :last_name => "player", :member_id => '123456', :card_id => '1234567890', :currency_id => 1, :status => "active", :property_id => 20000)
      @token = Token.create!(:session_token => 'abm39492i9jd9wjn', :player_id => 10, :expired_at => Time.now.utc + 1800)
      allow_any_instance_of(LaxSupport::AuthorizedRWS::Parser).to receive(:verify).and_return([20000])
    end

    after(:each) do
      Token.delete_all
      Player.delete_all
      clean_dbs
    end

    it '[32.1] Logout success' do
      get 'discard', {:session_token => 'abm39492i9jd9wjn', :login_name => '123456', :property_id => 20000}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'OK'
      expect(result[:error_msg]).to eq 'Request is carried out successfully.'
      token_test = Token.find_by_session_token('abm39492i9jd9wjn')
      token_test.expired_at.strftime("%Y-%m-%d %H:%M:%S UTC").should == (Time.now.utc - 100).strftime("%Y-%m-%d %H:%M:%S UTC")
    end

    it '[32.2] Logout fail' do
      get 'discard', {:session_token => 'abm394929wjn', :login_name => '123456', :property_id => 20000}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'InvalidSessionToken'
      expect(result[:error_msg]).to eq 'Session token is invalid.'
    end
  end

  describe '[33] Cage API: Keep Alive' do
    before(:each) do
      clean_dbs
      bypass_rescue
      @player = Player.create!(:id => 10, :first_name => "test", :last_name => "player", :member_id => '123456', :card_id => '1234567890', :currency_id => 1, :status => "active", :property_id => 20000)
      @token = Token.create!(:session_token => 'abm39492i9jd9wjn', :player_id => 10, :expired_at => Time.now + 1800)
      allow_any_instance_of(LaxSupport::AuthorizedRWS::Parser).to receive(:verify).and_return([20000])
    end

    after(:each) do
      Token.delete_all
      Player.delete_all
      clean_dbs
    end

    it '[33.1] Keep alive success' do
      post 'keep_alive', {:session_token => 'abm39492i9jd9wjn', :login_name => '123456', :property_id => 20000}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'OK'
      expect(result[:error_msg]).to eq 'Request is carried out successfully.'
      @token.expired_at.strftime("%Y-%m-%d %H:%M:%S UTC").should == (Time.now.utc + 1800).strftime("%Y-%m-%d %H:%M:%S UTC")
    end

    it '[33.2] Keep alive fail with wrong token' do
      post 'keep_alive', {:session_token => 'abm394jd9wjn', :login_name => '123456', :property_id => 20000}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'InvalidSessionToken'
      expect(result[:error_msg]).to eq 'Session token is invalid.'
    end

    # it '[33.3] Keep alive timeout' do
    #   @token2 = Token.create!(:session_token => 'abcdddd123', :player_id => 10, :terminal_id => '1234567892', :expired_at => Time.now - 1800, :property_id => 20000)
    #   post 'keep_alive', {:session_token => 'abcdddd123', :login_name => '123456'}
    #   result = JSON.parse(response.body).symbolize_keys
    #   expect(result[:error_code]).to eq 'InvalidSessionToken'
    #   expect(result[:error_msg]).to eq 'Session token is invalid.'
    # end
  end

  describe '[41] get player Currency API ' do
    before(:each) do
      clean_dbs
      bypass_rescue
      @player = Player.create!(:id => 10, :first_name => "test", :last_name => "player", :member_id => '123456', :card_id => '1234567890', :currency_id => 1, :status => "active", :property_id => 20000)
      allow_any_instance_of(LaxSupport::AuthorizedRWS::Parser).to receive(:verify).and_return([20000])
    end

    after(:each) do
      Player.delete_all
      clean_dbs
    end

    it '[41.1] Return Currency' do
      get 'get_player_currency', {:login_name => @player.member_id, :property_id => @player.property_id}
      result = JSON.parse(response.body).symbolize_keys
      expect(result[:error_code]).to eq 'OK'
      expect(result[:error_msg]).to eq 'Request is carried out successfully.'
      expect(result[:currency]).to eq 'HKD'
    end
  end
end
