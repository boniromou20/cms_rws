require "feature_spec_helper"

describe PlayersController do
  before(:all) do
    include Warden::Test::Helpers
    Warden.test_mode!
  end

  after(:all) do
    Warden.test_reset!
  end

  before(:each) do
    create_config(:daily_deposit_limit, 2000000)
    create_config(:daily_deposit_limit, 2000000, 10010)
    create_config(:daily_withdraw_limit, 2000000)
    create_config(:daily_withdraw_limit, 2000000, 10010)
  end

  describe '[4] Search player by membership ID' do
    before(:each) do
      mock_cage_info

      mock_wallet_balance(0.0)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})
    end

    it '[4.1] Show search Page' do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.balance")
      check_search_page
    end

    it '[4.2] successfully search player' do
      @player = create_default_player(:first_name => "exist", :last_name => "player")
      @player_10010 = create_default_player(:first_name => "exist", :last_name => "player", :licensee_id => 10010)
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      check_balance_page
      check_player_info
      expect(find("select#select_casino").value).to eq @root_user.casino_id.to_s
    end

    it '[4.5] successfully search player - Licensee 10010' do
      @player = create_default_player(:first_name => "exist", :last_name => "player")
      @player_10010 = create_default_player(:first_name => "exist", :last_name => "player", :licensee_id => 10010)
      login_as_10010
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player_10010.member_id)
      find("#button_find").click
      check_balance_page
      check_player_info_10010
      expect(find("select#select_casino").value).to eq @root_user.casino_id.to_s
    end

    it '[4.3] fail to search player' do
      allow_any_instance_of(Requester::Patron).to receive(:get_player_info).and_raise(Remote::PlayerNotFound)
      @player = Player.new
      @player.member_id = 12345
      @player.first_name = "test"
      @player.last_name = "player"
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      check_not_found
    end

    it '[4.4] fail to search other licensee player' do
      create_casino(1003)
      mock_player_info_result({:error_code => 'not OK'})
      @player = create_default_player(:first_name => "exist", :last_name => "player", :licensee_id => 1003)
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      check_not_found('search_error.not_validated')
    end
  end

  describe '[5] Balance Enquiry' do
    before(:each) do
      mock_cage_info

      mock_wallet_balance(0.0)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})
    end

    it '[5.1] view player balance enquiry', :js => true do
      mock_wallet_balance(99.99)

      @player = create_default_player(:first_name => "exist", :last_name => "player")
      login_as_admin

      mock_have_active_location

      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_search_page
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click

      check_player_info
      check_balance_page(9999)

      expect(page.source).to have_selector("div a#balance_deposit")
      expect(page.source).to have_selector("div a#balance_withdraw")
      expect(find("div a#balance_deposit")[:disabled]).to eq nil
      expect(find("div a#balance_withdraw")[:disabled]).to eq nil

      expect(find("select#select_casino").value).to eq @root_user.casino_id.to_s
    end

    it '[5.2] click unauthorized action', :js => true do
      login_as_test_user
      set_permission(@test_user,"cashier",:player,["balance"])
      visit home_path
      set_permission(@test_user,"cashier",:player,[])
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end

    it '[5.3] click link to the unauthorized page', :js => true do
      login_as_test_user
      set_permission(@test_user,"cashier",:player,[])
      visit balance_path
      wait_for_ajax
      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end

    it '[5.4] authorized to search and unauthorized to create' do
      allow_any_instance_of(Requester::Patron).to receive(:get_player_info).and_raise(Remote::PlayerNotFound)
      login_as_test_user
      set_permission(@test_user,"cashier",:player,["balance"])
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", 123456)

      find("#button_find").click
      check_not_found
      expect(page.source).to_not have_content(I18n.t("search_error.create_player"))
    end

    it '[5.5] Return to Cage home', :js => true do
      login_as_admin

      visit home_path
      mock_wallet_balance(99.99)
      mock_have_active_location

      @player = create_default_player(:first_name => "exist", :last_name => "player")
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_search_page
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click

      check_balance_page(9999)
      check_player_info

      expect(page.source).to have_selector("div a#balance_deposit")
      expect(page.source).to have_selector("div a#balance_withdraw")

      click_link I18n.t("tree_panel.home")
      check_home_page
    end

    it '[5.6] unauthorized to all actions' do
      mock_wallet_balance(99.99)

      @player = create_default_player(:first_name => "exist", :last_name => "player")
      login_as_test_user
      set_permission(@test_user,"cashier",:player,["balance"])
      set_permission(@test_user,"cashier",:player_transaction,[])
      visit home_path
      click_link I18n.t("tree_panel.balance")
      check_search_page
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click

      check_balance_page(9999)
      check_player_info

      expect(page.source).to_not have_selector("div a#balance_deposit")
      expect(page.source).to_not have_selector("div a#balance_withdraw")
    end

    it '[5.7] unathorized to balance enquriy ' do
      login_as_test_user
      set_permission(@test_user,"cashier",:player,[])
      visit home_path
      expect(first("aside#left-panel ul li#nav_balance_enquiry")).to eq nil
    end

    it '[5.8] balance enquiry with locked player', :js => true do
      mock_wallet_balance(99.99)
      mock_have_active_location

      @player = create_default_player(:first_name => "exist", :last_name => "player", :status => "locked")
      @player.lock_account!
      login_as_admin

      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_search_page
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click

      check_player_info
      check_balance_page(9999)

      expect(page).to have_selector("div a#balance_deposit")
      expect(page).to have_selector("div a#balance_withdraw")
      expect(find("div a#balance_deposit")[:disabled]).to eq 'disabled'
      expect(find("div a#balance_withdraw")[:disabled]).to eq 'disabled'
    end

    it '[5.10] View player balance enquiry based on casino selected', :js => true do
    #not finish
      create_casino(1003)
      create_config(:deposit_authorized_amount, 5000000)
      create_transaction_slip_type
      mock_close_after_print
      mock_patron_not_change
      mock_have_active_location
      @player = create_default_player

      mock_wallet_balance(0.0)
      mock_wallet_transaction_success(:deposit)

      login_as_admin_multi_casino

      #test = Rails.cache.fetch "#{@root_user.uid}"
      #p 'test...', test[:casinos]

      go_to_deposit_page
      wait_for_ajax
      check_remain_amount(:deposit)
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("#player_transaction_source_of_funds option[value='2']").select_option

      find("button#confirm_deposit").click
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      find("div#pop_up_dialog div button#confirm").click

      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_search_page
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click

      expect(find("select#select_casino").value).to eq @root_user.casino_id.to_s
      expect(find("label#player_remain_deposit").text).to eq to_display_amount_str(10000)
      clean_dbs
      #create_shift_data_multi
      #select('test', :from => 'select_casino')
      #expect(find("select#select_casino").value).to eq '1003'
      #Rails.logger.info '-----------------------'
      #wait_for_ajax
      #Rails.logger.info '========================'
      #expect(find("label#player_remain_deposit").text).to eq to_display_amount_str(1000000)
    end
  end

  describe '[12] Search player by card ID' do
    before(:each) do
      mock_cage_info

      mock_wallet_balance(0.0)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})
    end

    it '[12.1] Show search Page' do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.balance")
      check_search_page
    end

    it '[12.2] successfully search player' do
      @player = create_default_player(:first_name => "exist", :last_name => "player")
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("card_id", @player.card_id)
      find("#button_find").click
      check_balance_page
      check_player_info
    end

    it '[12.3] fail to search player' do
      allow_any_instance_of(Requester::Patron).to receive(:get_player_info).and_raise(Remote::PlayerNotFound)
      @player = Player.new
      @player.member_id = 123456
      @player.card_id = 1234567890
      @player.first_name = "test"
      @player.last_name = "player"
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("card_id", @player.card_id)
      find("#button_find").click
      check_not_found
    end
  end

=begin
  describe '[15] Lock/Unlock Player' do
    def update_lock_or_unlock
      if @player.status == 'active'
        @lock_or_unlock = "lock"
      else
        @lock_or_unlock = "unlock"
      end
    end

    def check_lock_unlock_components
      expect(page).to have_selector "div#pop_up_dialog"
      expect(find("div#pop_up_dialog")[:style]).to include "none"
    end

    def check_lock_unlock_page
      @player.reload
      update_lock_or_unlock

      check_profile_page
      check_player_info
      check_lock_unlock_components
    end

    def search_player_profile
      fill_search_info_js("card_id", @player.card_id)
      find("#button_find").click
      wait_for_ajax
    end

    def toggle_player_lock_status_and_check
      check_lock_unlock_page

      click_button I18n.t("button.#{@lock_or_unlock}")
      expect(find("div#pop_up_dialog")[:style]).to_not include "none"

      expected_flash_message = I18n.t("#{@lock_or_unlock}_player.success", name: @player.member_id)

      click_button I18n.t("button.confirm")
      wait_for_ajax

      check_lock_unlock_page
      check_flash_message expected_flash_message
    end

    def lock_or_unlock_player_and_check
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      search_player_profile
      toggle_player_lock_status_and_check
    end

    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info

      @player = create_default_player(:first_name => "test", :last_name => "player")

      mock_wallet_balance(0.0)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})
    end

    after(:each) do
      clean_dbs
    end

    it '[15.1] Successfully Lock player', js: true do
      lock_or_unlock_player_and_check
    end

    it '[15.2] Successfully unlock player', js: true do
      @player.status = "locked"
      @player.save
      @players_lock_type = PlayersLockType.add_lock_to_player(@player.id,'cage_lock')

      lock_or_unlock_player_and_check
    end

    it '[15.3] unauthorized to lock/unlock' do
      login_as_test_user
      set_permission(@test_user,"cashier",:player,["profile"])
      visit home_path
      click_link I18n.t("tree_panel.profile")

      expect(page).to_not have_button I18n.t("button.lock")
      expect(page).to_not have_button I18n.t("button.unlock")
      expect(page).to_not have_selector "div#confirm_lock_player_dialog"
      expect(page).to_not have_selector "div#confirm_unlock_player_dialog"
    end

    it '[15.4] Audit log for lock player', js: true do
      lock_or_unlock_player_and_check

      audit_log = AuditLog.find_by_audit_target("player")
      expect(audit_log).to_not be_nil
      expect(audit_log.audit_target).to eq "player"
      expect(audit_log.action_by).to eq @root_user.name
      expect(audit_log.action_type).to eq "update"
      expect(audit_log.action).to eq "lock"
      expect(audit_log.action_status).to eq "success"
      expect(audit_log.action_error).to be_nil
      expect(audit_log.ip).to_not be_nil
      expect(audit_log.session_id).to_not be_nil
      expect(audit_log.description).to_not be_nil
    end

    it '[15.5] audit log for unlock player', js: true do
      @player.status = "locked"
      @player.save
      @players_lock_type = PlayersLockType.add_lock_to_player(@player.id,'cage_lock')

      lock_or_unlock_player_and_check

      audit_log = AuditLog.find_by_audit_target("player")
      expect(audit_log).to_not be_nil
      expect(audit_log.audit_target).to eq "player"
      expect(audit_log.action_by).to eq @root_user.name
      expect(audit_log.action_type).to eq "update"
      expect(audit_log.action).to eq "unlock"
      expect(audit_log.action_status).to eq "success"
      expect(audit_log.action_error).to be_nil
      expect(audit_log.ip).to_not be_nil
      expect(audit_log.session_id).to_not be_nil
      expect(audit_log.description).to_not be_nil
    end

    it '[15.6] Show cage lock and Blacklist player status ', js: true do
      @player.status = "locked"
      @player.save
      @players_lock_type = PlayersLockType.add_lock_to_player(@player.id,'cage_lock')
      @players_lock_type = PlayersLockType.add_lock_to_player(@player.id,'blacklist')

      lock_or_unlock_player_and_check
    end

    it '[15.7] Fail to lock player', js: true do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      search_player_profile
      check_lock_unlock_page

      @player.lock_account!

      click_button I18n.t("button.#{@lock_or_unlock}")
      expect(find("div#pop_up_dialog")[:style]).to_not include "none"

      expected_flash_message = I18n.t("#{@lock_or_unlock}_player.fail", name: @player.member_id)

      click_button I18n.t("button.confirm")
      wait_for_ajax

      check_lock_unlock_page
      check_flash_message expected_flash_message
    end

    it '[15.8] Fail to unlock player', js: true do
      @player.status = "locked"
      @player.save
      @players_lock_type = PlayersLockType.add_lock_to_player(@player.id,'cage_lock')
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      search_player_profile
      check_lock_unlock_page

      @player.unlock_account!

      click_button I18n.t("button.#{@lock_or_unlock}")
      expect(find("div#pop_up_dialog")[:style]).to_not include "none"

      expected_flash_message = I18n.t("#{@lock_or_unlock}_player.fail", name: @player.member_id)

      click_button I18n.t("button.confirm")
      wait_for_ajax

      check_lock_unlock_page
      check_flash_message expected_flash_message
    end
  end
=end

=begin
  describe '[36] Expire token' do
     before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info
      mock_wallet_balance(0.0)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})
      @player = create_default_player(:id => 10, :first_name => "test", :last_name => "player")
      @token1 = Token.create!(:session_token => 'abm39492i9jd9wjn', :player_id => 10, :expired_at => Time.now + 1800)
      @token2 = Token.create!(:session_token => '3949245469jd9wjn', :player_id => 10, :expired_at => Time.now + 1800)
      @player_10010 = create_default_player(:id => 10010, :first_name => "test", :last_name => "player", :licensee_id => 10010)
      @token3 = Token.create!(:session_token => 'asd39492i9jd9wjn', :player_id => 10010, :expired_at => Time.now + 1800)
    end

     after(:each) do
      Token.delete_all
      clean_dbs
    end

    it '[36.1] Expire token when player is locked from cage', js: true do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      fill_search_info_js("card_id", @player.card_id)
      find("#button_find").click
      wait_for_ajax

      @player.reload

      if @player.status == 'active'
        @lock_or_unlock = "lock"
      else
        @lock_or_unlock = "unlock"
      end

      check_profile_page
      check_player_info

      expect(page).to have_selector "div#pop_up_dialog"
      expect(find("div#pop_up_dialog")[:style]).to include "none"

      click_button I18n.t("button.#{@lock_or_unlock}")
      expect(find("div#pop_up_dialog")[:style]).to_not include "none"

      expected_flash_message = I18n.t("#{@lock_or_unlock}_player.success", name: @player.member_id)

      click_button I18n.t("button.confirm")
      wait_for_ajax

      @player.reload

      if @player.status == 'active'
        @lock_or_unlock = "lock"
      else
        @lock_or_unlock = "unlock"
      end

      check_profile_page
      check_player_info

      expect(page).to have_selector "div#pop_up_dialog"
      expect(find("div#pop_up_dialog")[:style]).to include "none"

      check_flash_message expected_flash_message
      token_test1 = Token.find_by_session_token('abm39492i9jd9wjn')
      token_test2 = Token.find_by_session_token('3949245469jd9wjn')
      token_test3 = Token.find_by_session_token('asd39492i9jd9wjn')
      expect(token_test1.expired_at.strftime("%Y-%m-%d %H:%M:%S UTC")).to be >= (Time.now.utc - 200).strftime("%Y-%m-%d %H:%M:%S UTC")
      expect(token_test1.expired_at.strftime("%Y-%m-%d %H:%M:%S UTC")).to be <= (Time.now.utc + 200).strftime("%Y-%m-%d %H:%M:%S UTC")
      expect(token_test2.expired_at.strftime("%Y-%m-%d %H:%M:%S UTC")).to be >= (Time.now.utc - 200).strftime("%Y-%m-%d %H:%M:%S UTC")
      expect(token_test2.expired_at.strftime("%Y-%m-%d %H:%M:%S UTC")).to be <= (Time.now.utc + 200).strftime("%Y-%m-%d %H:%M:%S UTC")
      expect(token_test3.expired_at.strftime("%Y-%m-%d %H:%M:%S UTC")).to be > (Time.now.utc + 1000).strftime("%Y-%m-%d %H:%M:%S UTC")
    end
  end
=end

  describe '[37] Show balance not found' do
    before(:each) do
      mock_cage_info
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})

    end

    it '[37.1] Player balance not found', :js => true do
      mock_wallet_balance('no_balance')

      @player = create_default_player(:first_name => "exist", :last_name => "player")
      login_as_admin

      mock_have_active_location

      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_search_page
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click

      check_player_info
      check_balance_page_without_balance

      expect(page.source).to have_selector("div a#balance_deposit")
      expect(page.source).to have_selector("div a#balance_withdraw")
      expect(find("div a#balance_deposit")[:disabled]).to eq nil
      expect(find("div a#balance_withdraw")[:disabled]).to eq nil

      check_flash_message I18n.t("balance_enquiry.query_balance_fail")

    end
  end

  describe '[38] Retry create player' do
    before(:each) do
      mock_cage_info
      mock_have_active_location
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})
      @player = create_default_player(:first_name => "exist", :last_name => "player")
    end

    # it '[38.1] Retry create player success', :js => true do
    #   @credit_expird_at = (Time.now + 2.day).utc.to_s
    #   allow_any_instance_of(LaxSupport::AuthorizedRWS::Base).to receive(:send).and_return({:error_code => 'InvalidLoginName'},{:error_code => 'OK', :balance => 99.99, :credit_balance => 99.99, :credit_expired_at => @credit_expird_at})
    #   allow_any_instance_of(Requester::Wallet).to receive(:remote_response_checking).and_return({:error_code => 'InvalidLoginName'},{:error_code => 'OK', :balance => 99.99, :credit_balance => 99.99, :credit_expired_at => @credit_expird_at})
    #   mock_wallet_response_success(:create_player)

    #   login_as_admin

    #   visit home_path
    #   click_link I18n.t("tree_panel.balance")
    #   wait_for_ajax
    #   check_search_page
    #   fill_search_info_js("member_id", @player.member_id)
    #   find("#button_find").click

    #   check_player_info
    #   check_balance_page(9999)

    #   expect(page.source).to have_selector("div a#balance_deposit")
    #   expect(page.source).to have_selector("div a#balance_withdraw")
    #   expect(find("div a#balance_deposit")[:disabled]).to eq nil
    #   expect(find("div a#balance_withdraw")[:disabled]).to eq nil
    # end

    it '[38.2] Retry create player  fail', :js => true do
      allow_any_instance_of(LaxSupport::AuthorizedRWS::Base).to receive(:send).and_return({:error_code => 'InvalidLoginName'})
      allow_any_instance_of(Requester::Wallet).to receive(:remote_response_checking).and_return({:error_code => 'InvalidLoginName'})

      login_as_admin

      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_search_page
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click
      wait_for_ajax

      check_player_info
      check_balance_page_without_balance

      expect(page.source).to have_selector("div a#balance_deposit")
      expect(page.source).to have_selector("div a#balance_withdraw")
      expect(find("div a#balance_deposit")[:disabled]).to eq nil
      expect(find("div a#balance_withdraw")[:disabled]).to eq nil
    end
  end

  describe '[53] Update player info when search in Balance Enquiry/Player Profile' do
    before(:each) do
      mock_cage_info

      mock_wallet_balance(0.0)
      @player = create_default_player(:first_name => "exist", :last_name => "player")
    end

    it '[53.1] Show PIS player info when search  Player Profile without change' do
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => @player.card_id, :member_id => @player.member_id, :blacklist => @player.has_lock_type?('blacklist'), :pin_status => 'created', :licensee_id => 20000}})
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("card_id", @player.card_id)
      find("#button_find").click
      #check_profile_page
      check_balance_page
      check_player_info
      p = Player.find(@player.id)
      expect(p.member_id).to eq @player.member_id
      expect(p.card_id).to eq @player.card_id
      expect(p.status).to eq @player.status
    end

    it '[53.2] Show PIS player info when search  Player Profile with Card ID changed' do
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567891', :member_id => @player.member_id, :blacklist => @player.has_lock_type?('blacklist'), :pin_status => 'created', :licensee_id => 20000}})
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      #check_profile_page
      check_balance_page
      p = Player.find(@player.id)
      expect(p.member_id).to eq @player.member_id
      expect(p.card_id).to eq '1234567891'
      expect(p.status).to eq @player.status
    end

    it '[53.3] Show PIS player info when search  Player Profile with blacklist changed' do
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => @player.card_id, :member_id => @player.member_id, :blacklist => true, :pin_status => 'created', :licensee_id => 20000}})
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("card_id", @player.card_id)
      find("#button_find").click
      #check_profile_page
      check_balance_page
      p = Player.find(@player.id)
      expect(p.member_id).to eq @player.member_id
      expect(p.card_id).to eq @player.card_id
      expect(p.status).to eq 'locked'
      expect(p.has_lock_type?('blacklist')).to eq true
    end

    it '[53.4] Show PIS player info when search  Player Profile PIN changed' do
      Token.generate(@player.id, 20000)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => @player.card_id, :member_id => @player.member_id, :blacklist => @player.has_lock_type?('blacklist'), :pin_status => 'reset', :licensee_id => 20000}})
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("card_id", @player.card_id)
      find("#button_find").click
      #check_profile_page
      check_balance_page
      check_player_info
      p = Player.find(@player.id)
      expect(p.member_id).to eq @player.member_id
      expect(p.card_id).to eq @player.card_id
      expect(p.status).to eq @player.status
      expect(@player.valid_tokens).to eq []
    end

    # it '[53.5] Show PIS player info when search  Player Profile, player not exist in Cage' do
    #   @player.delete
    #   @player = Player.new(:first_name => "exist", :last_name => "player", :member_id => '123456', :card_id => '1234567890', :currency_id => 2, :status => "active")
    #   mock_player_info_result({:error_code => 'OK', :player => {:card_id => @player.card_id, :member_id => @player.member_id, :blacklist => @player.has_lock_type?('blacklist'), :pin_status => 'blank', :licensee_id => 20000}})
    #   login_as_admin
    #   visit players_search_path + "?operation=balance"
    #   fill_search_info("card_id", @player.card_id)
    #   find("#button_find").click
    #   #check_profile_page('no_balance')
    #   check_balance_page('no_balance')
    #   expect(find("label#player_member_id").text).to eq @player.member_id.to_s
    #   expect(find("label#player_card_id").text).to eq @player.card_id.to_s.gsub(/(\d{4})(?=\d)/, '\\1-')
    #   expect(find("label#player_status").text).to eq I18n.t("player_status.not_activate")
    #   #expect(page.source).to have_selector("a#create_pin")
    # end

    it '[53.6] Card ID not found in PIS' do
      allow_any_instance_of(Requester::Patron).to receive(:get_player_info).and_raise(Remote::PlayerNotFound)
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("card_id", @player.card_id)
      find("#button_find").click
      #check_profile_page
      check_balance_page
      p = Player.find(@player.id)
      expect(p.member_id).to eq @player.member_id
      expect(p.card_id).to eq @player.card_id
      expect(p.status).to eq @player.status
    end

    it '[53.7] Show PIS player info when search balance enquiry with Card ID changed' do
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567891', :member_id => @player.member_id, :blacklist => @player.has_lock_type?('blacklist'), :pin_status => 'created', :licensee_id => 20000}})
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      check_balance_page
      p = Player.find(@player.id)
      expect(p.member_id).to eq @player.member_id
      expect(p.card_id).to eq '1234567891'
      expect(p.status).to eq @player.status
    end
  end

=begin
  describe '[54] Reset/Create PIN (PIS)' do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info

      mock_wallet_balance(0.0)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => "1234567890", :member_id => "123456", :blacklist => false, :pin_status => 'blank', :licensee_id => 20000, :test_mode_player => false}})
    end

    after(:each) do
      clean_dbs
    end

    it '[54.1] Create PIN success in player profile', js: true do
      mock_reset_pin_result({:error_code => 'OK', :player => {:card_id => "1234567890", :member_id => "123456", :blacklist => false, :pin_status => 'created', :licensee_id => 20000, :test_mode_player => false}})
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      fill_search_info_js("card_id", "1234567890")
      find("#button_find").click
      wait_for_ajax

      check_title("tree_panel.profile")
      expect(find("label#player_balance").text).to eq '--'
      expect(find("label#player_member_id").text).to eq '123456'
      expect(find("label#player_card_id").text).to eq '1234567890'.gsub(/(\d{4})(?=\d)/, '\\1-')
      expect(find("label#player_status").text).to eq I18n.t("player_status.not_activate")

      find("#create_pin").click

      wait_for_ajax
      check_title("tree_panel.create_pin")
      fill_in "new_pin", :with => '1111'
      fill_in "confirm_pin", :with => '1111'
      content_list = [I18n.t("confirm_box.set_pin", member_id: '123456')]
      click_pop_up_confirm("confirm_set_pin", content_list)

      wait_for_ajax
      check_flash_message I18n.t("reset_pin.set_pin_success", name: "123456")
    end

    it '[54.2] Create PIN fail with PIN is too short in player profile', js: true do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      fill_search_info_js("card_id", "1234567890")
      find("#button_find").click
      wait_for_ajax

      check_title("tree_panel.profile")
      expect(find("label#player_balance").text).to eq '--'
      expect(find("label#player_member_id").text).to eq '123456'
      expect(find("label#player_card_id").text).to eq '1234567890'.gsub(/(\d{4})(?=\d)/, '\\1-')
      expect(find("label#player_status").text).to eq I18n.t("player_status.not_activate")

      find("#create_pin").click

      wait_for_ajax
      check_title("tree_panel.create_pin")
      fill_in "new_pin", :with => '11'
      fill_in "confirm_pin", :with => '11'
      find("#confirm_set_pin").click
      expect(page).to have_selector('#length_error', visible: true)
      expect(page).to have_selector('#not_match_error', visible: false)
      # expect(find("#length_error").style('')).to eq I18n.t("reset_pin.length_error")
    end

    it '[54.3] Create PIN fail with 2 different PIN in player profile', js: true do
      mock_reset_pin_result({:error_code => 'OK', :player => {:card_id => "1234567890", :member_id => "123456", :blacklist => false, :pin_status => 'created', :licensee_id => 20000}})
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      fill_search_info_js("card_id", "1234567890")
      find("#button_find").click
      wait_for_ajax

      check_title("tree_panel.profile")
      expect(find("label#player_balance").text).to eq '--'
      expect(find("label#player_member_id").text).to eq '123456'
      expect(find("label#player_card_id").text).to eq '1234567890'.gsub(/(\d{4})(?=\d)/, '\\1-')
      expect(find("label#player_status").text).to eq I18n.t("player_status.not_activate")

      find("#create_pin").click

      wait_for_ajax
      check_title("tree_panel.create_pin")
      fill_in "new_pin", :with => '1111'
      fill_in "confirm_pin", :with => '2222'
      find("#confirm_set_pin").click
      expect(page).to have_selector('#length_error', visible: false)
      expect(page).to have_selector('#not_match_error', visible: true)
    end

    it '[54.4] Reset PIN success in player profile', js: true do
      @player = create_default_player(:first_name => "exist", :last_name => "player")
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => "1234567890", :member_id => "123456", :blacklist => false, :pin_status => 'created', :licensee_id => 20000}})
      mock_reset_pin_result({:error_code => 'OK', :player => {:card_id => "1234567890", :member_id => "123456", :blacklist => false, :pin_status => 'reset', :licensee_id => 20000}})
      mock_wallet_balance(0.0)
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      fill_search_info_js("member_id", "123456")
      find("#button_find").click
      wait_for_ajax

      check_title("tree_panel.profile")
      expect(find("label#player_balance").text).to eq '0.00'
      expect(find("label#player_member_id").text).to eq '123456'
      expect(find("label#player_card_id").text).to eq '1234567890'.gsub(/(\d{4})(?=\d)/, '\\1-')
      expect(find("label#player_status").text).to eq I18n.t("player_status.active")

      find("#reset_pin").click

      wait_for_ajax
      check_title("tree_panel.reset_pin")
      fill_in "new_pin", :with => '1111'
      fill_in "confirm_pin", :with => '1111'
      content_list = [I18n.t("confirm_box.set_pin", member_id: '123456')]
      click_pop_up_confirm("confirm_set_pin", content_list)

      wait_for_ajax
      check_flash_message I18n.t("reset_pin.set_pin_success", name: "123456")
    end

    it '[54.5] Create PIN success in balance enquiry', js: true do
      mock_reset_pin_result({:error_code => 'OK', :player => {:card_id => "1234567890", :member_id => "123456", :blacklist => false, :pin_status => 'created', :licensee_id => 20000, :test_mode_player => false}})
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax

      check_search_page

      fill_search_info_js("member_id", "123456")
      find("#button_find").click
      wait_for_ajax

      check_title("tree_panel.balance")
      expect(find("label#player_balance").text).to eq '--'
      expect(find("label#player_member_id").text).to eq '123456'
      expect(find("label#player_card_id").text).to eq '1234567890'.gsub(/(\d{4})(?=\d)/, '\\1-')
      expect(find("label#player_status").text).to eq I18n.t("player_status.not_activate")

      find("#create_pin").click

      wait_for_ajax
      check_title("tree_panel.create_pin")
      fill_in "new_pin", :with => '1111'
      fill_in "confirm_pin", :with => '1111'
      content_list = [I18n.t("confirm_box.set_pin", member_id: '123456')]
      click_pop_up_confirm("confirm_set_pin", content_list)

      wait_for_ajax
      check_flash_message I18n.t("reset_pin.set_pin_success", name: "123456")
    end

    it '[54.6] Create PIN fail in balance enquiry', js: true do
      mock_reset_pin_result('connection fail')
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax

      check_search_page

      fill_search_info_js("member_id", "123456")
      find("#button_find").click
      wait_for_ajax

      check_title("tree_panel.balance")
      expect(find("label#player_balance").text).to eq '--'
      expect(find("label#player_member_id").text).to eq '123456'
      expect(find("label#player_card_id").text).to eq '1234567890'.gsub(/(\d{4})(?=\d)/, '\\1-')
      expect(find("label#player_status").text).to eq I18n.t("player_status.not_activate")

      find("#create_pin").click

      wait_for_ajax
      check_title("tree_panel.create_pin")
      fill_in "new_pin", :with => '1111'
      fill_in "confirm_pin", :with => '1111'
      content_list = [I18n.t("confirm_box.set_pin", member_id: '123456')]
      click_pop_up_confirm("confirm_set_pin", content_list)

      wait_for_ajax
      check_flash_message I18n.t("reset_pin.call_patron_fail")
    end
  end
=end

=begin
  describe '[59] Show Promotional Credit' do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info
      mock_have_active_location

      mock_player_info_result({:error_code => 'OK'})
    end

    after(:each) do
      clean_dbs
    end

    def check_footer_btn(deposit,withdraw,credit_deposit,credit_expire)
      expect(page.source).to have_selector("div a#balance_deposit")
      expect(page.source).to have_selector("div a#balance_withdraw")
      expect(page.source).to have_selector("div a#credit_deposit")
      expect(page.source).to have_selector("div a#credit_expire")
      expect(find("div a#balance_deposit")[:disabled]).to eq btn_disable_status(deposit)
      expect(find("div a#balance_withdraw")[:disabled]).to eq btn_disable_status(withdraw)
      expect(find("div a#credit_deposit")[:disabled]).to eq btn_disable_status(credit_deposit)
      expect(find("div a#credit_expire")[:disabled]).to eq btn_disable_status(credit_expire)
    end

    def btn_disable_status(status)
      if status
        nil
      else
        'disabled'
      end
    end

    def check_credit_balance_base
      @player = create_default_player(:first_name => "exist", :last_name => "player")
      login_as_admin

      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_search_page
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click

      check_player_info
    end

    it '[59.1] seach player profile with credit balance=0', :js => true do
      mock_wallet_balance(99.99,0.0)

      check_credit_balance_base

      check_balance_page(9999,0,"")

      check_footer_btn(true,true,true,false)
    end

    it '[59.2] seach player profile with credit balance=100', :js => true do
      credit_expired_at = (Time.now + 2.day).strftime("%Y-%m-%d %H:%M:%S")
      mock_wallet_balance(99.99,100.0, credit_expired_at)

      check_credit_balance_base

      check_balance_page(9999,10000, I18n.t("balance_enquiry.expiry",expired_at: credit_expired_at.to_time(:local).strftime("%F %R")))

      check_footer_btn(true,true,false,true)
    end

    it '[59.3] seach player profile with disconnect with wallet', :js => true do
      mock_wallet_balance('no_balance','no_balance')

      check_credit_balance_base

      check_balance_page('no_balance','no_balance', "")

      check_footer_btn(true,true,false,false)
    end
  end
=end

=begin
  describe '[71] Test mode player - player profile' do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info

      mock_wallet_balance(0.0)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})
    end

    after(:each) do
      clean_dbs
    end

    it '[71.1] Show test mode player info, disappear reset PIN and lock button', :js => true do
      mock_wallet_balance(99.99)

      @player = create_default_player(:first_name => "exist", :last_name => "player", :test_mode_player => true)
      login_as_admin

      mock_have_active_location

      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax
      check_search_page('profile')
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click

      check_player_info
      check_profile_page(9999)

      expect(page.source).to_not have_selector("a#reset_pin")
      expect(page.source).to_not have_selector("div#button_set button#lock_player")
    end
  end
=end

  describe '[72] Test mode player - Balance enquiry' do
    before(:each) do
      mock_cage_info

      mock_wallet_balance(0.0)
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => '1234567890', :member_id => '123456', :blacklist => false, :pin_status => 'used', :licensee_id => 20000}})
    end

    it '[72.1] Show test mode player info, disappear deposit and withdraw, add credit and expire credit button', :js => true do
      mock_wallet_balance(99.99)

      @player = create_default_player(:first_name => "exist", :last_name => "player", :test_mode_player => true)
      login_as_admin

      mock_have_active_location

      visit home_path
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_search_page
      fill_search_info_js("member_id", @player.member_id)
      find("#button_find").click

      check_player_info
      check_balance_page(9999)

      expect(page.source).to_not have_selector("a#balance_deposit")
      expect(page.source).to_not have_selector("a#balance_withdraw")
      expect(page.source).to_not have_selector("a#credit_deposit")
      expect(page.source).to_not have_selector("a#credit_expire")

    end
  end

=begin
  describe '[75] Do not allow test mode player to reset PIN or Lock', :js => true do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info
      mock_close_after_print
      mock_patron_not_change
      mock_have_active_location
      @player = create_default_player

      mock_wallet_balance(0.0)
      mock_wallet_transaction_success(:deposit)
    end

    after(:each) do
      clean_dbs
    end

    it '[75.1] Reset PIN fail due to test mode player', js: true do
      mock_player_info_result({:error_code => 'OK', :player => {:card_id => "1234567890", :member_id => "123456", :blacklist => false, :pin_status => 'created', :licensee_id => 20000}})
      mock_reset_pin_result({:error_code => 'OK', :player => {:card_id => "1234567890", :member_id => "123456", :blacklist => false, :pin_status => 'reset', :licensee_id => 20000}})
      mock_wallet_balance(0.0)
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      fill_search_info_js("member_id", "123456")
      find("#button_find").click
      wait_for_ajax

      check_title("tree_panel.profile")
      expect(find("label#player_balance").text).to eq '0.00'
      expect(find("label#player_member_id").text).to eq '123456'
      expect(find("label#player_card_id").text).to eq '1234567890'.gsub(/(\d{4})(?=\d)/, '\\1-')
      expect(find("label#player_status").text).to eq I18n.t("player_status.active")

      find("#reset_pin").click

      wait_for_ajax
      check_title("tree_panel.reset_pin")
      fill_in "new_pin", :with => '1111'
      fill_in "confirm_pin", :with => '1111'
      content_list = [I18n.t("confirm_box.set_pin", member_id: '123456')]

      @player.test_mode_player = true
      @player.save!
      click_pop_up_confirm("confirm_set_pin", content_list)

      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end


    it '[75.2] Lock player fail due to test mode player', js: true do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.profile")
      wait_for_ajax

      check_search_page("profile")

      search_player_profile
      check_lock_unlock_page

      click_button I18n.t("button.#{@lock_or_unlock}")
      expect(find("div#pop_up_dialog")[:style]).to_not include "none"

      @player.test_mode_player = true
      @player.save!

      click_button I18n.t("button.confirm")
      wait_for_ajax

      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end
  end
=end
end
