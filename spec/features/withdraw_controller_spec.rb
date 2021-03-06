require "feature_spec_helper"

describe WithdrawController do
  before(:all) do
    include Warden::Test::Helpers
    Warden.test_mode!
  end

  after(:all) do
    Warden.test_reset!
  end

  describe '[7] Withdraw' do
    before(:each) do
      create_config(:audit_log_search_range, 7)
      create_config(:daily_deposit_limit, 2000000)
      create_config(:daily_withdraw_limit, 2000000)
      create_config(:withdraw_authorized_amount, 5000000)
      create_transaction_slip_type('withdraw')
      mock_cage_info
      mock_close_after_print
      mock_patron_not_change
      mock_have_active_location
      @player = create_default_player
      @player_balance = 20000
      mock_wallet_balance(200.0)
      mock_wallet_transaction_success(:withdraw)
      allow_any_instance_of(Requester::Patron).to receive(:validate_pin).and_return(Requester::ValidatePinResponse.new({}))
      allow_any_instance_of(RequesterHelper).to receive(:validate_pin).and_return(true)
    end

    it '[7.1] show Withdraw page', :js => true do
      login_as_admin
      go_to_withdraw_page
      wait_for_ajax
      check_title("tree_panel.fund_out")
      check_player_info
      expect(page.source).to have_selector("button#confirm")
      expect(page.source).to have_selector("button#cancel")
    end

    it '[7.2] Invalid Withdraw', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 1.111
      expect(find("input#player_transaction_amount").value).to eq "1.11"
    end

    it '[7.3] Invalid Withdraw(eng)', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => "abc3de"
      expect(find("input#player_transaction_amount").value).to eq ""
    end

    it '[7.4] Invalid Withdraw (input 0 amount)', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => ""
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq false
      expect(find("label#amount_error").text).to eq I18n.t("invalid_amt.withdraw")
      expect(find("label#amount_error")[:style].include?("block")).to eq true
    end

    it '[7.5] Invalid Withdraw (invalid balance)', :js => true do
      allow_any_instance_of(Requester::Wallet).to receive(:withdraw).and_raise(Remote::AmountNotEnough.new("200.0"))

      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 300
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      find("div#pop_up_dialog div button#confirm").click
      check_title("tree_panel.fund_out")
      expect(find("label#player_full_name").text).to eq @player.full_name.upcase
      expect(find("label#player_member_id").text).to eq @player.member_id.to_s
      check_flash_message I18n.t("invalid_amt.no_enough_to_withdraw", { balance: to_display_amount_str(@player_balance)})
    end

    it '[7.6] cancel Withdraw', :js => true do
      login_as_admin
      go_to_withdraw_page
      find("a#cancel").click

      wait_for_ajax
      check_balance_page(@player_balance)
    end

    it '[7.7] Confirm Withdraw', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
    end

    it '[7.8] Cancel dialog box Withdraw', :js => true do
      login_as_admin
      go_to_withdraw_page
      wait_for_ajax
      check_remain_amount(:withdraw)
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      find("div#pop_up_dialog div button#cancel").trigger('click')
      sleep(5)
      expect(find("div#pop_up_dialog")[:class].include?("fadeOut")).to eq true
      expect(find("div#pop_up_dialog")[:style].include?("none")).to eq true
    end


    it '[7.9] Confirm dialog box Withdraw', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      find("div#pop_up_dialog div button#confirm").click
      expect(first("div div h1").text).to include I18n.t("tree_panel.fund_out")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
    end

    it '[7.10] audit log for confirm dialog box Withdraw', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      wait_for_ajax
      find("div#pop_up_dialog div button#confirm").click
      wait_for_ajax
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")

      audit_log = AuditLog.find_by_audit_target("player")
      expect(audit_log).to_not eq nil
      expect(audit_log.audit_target).to eq "player"
      expect(audit_log.action_by).to eq @root_user.name
      expect(audit_log.action_type).to eq "update"
      expect(audit_log.action).to eq "withdraw"
      expect(audit_log.action_status).to eq "success"
      expect(audit_log.action_error).to eq nil
      expect(audit_log.ip).to_not eq nil
      expect(audit_log.session_id).to_not eq nil
      expect(audit_log.description).to_not eq nil
    end

    it '[7.11] click unauthorized action (Withdraw)' do
      login_as_test_user
      set_permission(@test_user,"cashier",:player,["balance"])
      set_permission(@test_user,"cashier",:player_transaction,["withdraw"])
      visit home_path
      click_link I18n.t("tree_panel.balance")
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click

      expect(find("label#player_full_name").text).to eq @player.full_name.upcase
      expect(find("label#player_member_id").text).to eq @player.member_id.to_s
      expect(find("label#player_balance").text).to eq to_display_amount_str(@player_balance)
      set_permission(@test_user,"cashier",:player,[])
      set_permission(@test_user,"cashier",:player_transaction,[])

      find("div a#balance_withdraw").click

      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end

    it '[7.12] click link to the unauthorized page' do
      login_as_test_user
      set_permission(@test_user,"cashier",:player_transaction,[])
      visit fund_out_path + "?member_id=#{@player.member_id}"
      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end

    it '[7.13] click unauthorized action (confirm dialog box Withdraw)', :js => true do
      login_as_test_user
      set_permission(@test_user,"cashier",:player,["balance"])
      set_permission(@test_user,"cashier",:player_transaction,["withdraw"])
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      set_permission(@test_user,"cashier",:player_transaction,[])
      find("div#pop_up_dialog div button#confirm").click
      wait_for_ajax

      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end

    it '[7.14] click unauthorized action (print slip)', :js => true do
      login_as_test_user
      set_permission(@test_user,"cashier",:player,["balance"])
      set_permission(@test_user,"cashier",:player_transaction,["withdraw"])
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      find("div#pop_up_dialog div button#confirm").click

      expect(first("div div h1").text).to include I18n.t("tree_panel.fund_out")
      expect(page).to have_selector("table")
      expect(page).to_not have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
    end

    it '[7.15] Print slip', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      find("div#pop_up_dialog div button#confirm").click

      expect(first("div div h1").text).to include I18n.t("tree_panel.fund_out")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")

      mock_wallet_balance(100.0)

      find("button#print_slip").click
      expect(page.source).to have_selector("iframe")
      wait_for_ajax
      check_balance_page(@player_balance - 10000)
    end

    it '[7.16] Close slip', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      find("div#pop_up_dialog div button#confirm").click

      expect(first("div div h1").text).to include I18n.t("tree_panel.fund_out")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")

      mock_wallet_balance(100.0)

      find("a#close_link").click
      wait_for_ajax
      check_balance_page(@player_balance - 10000)
    end

    it '[7.17] audit log for print slip', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      find("div#pop_up_dialog div button#confirm").click

      expect(first("div div h1").text).to include I18n.t("tree_panel.fund_out")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")

      mock_wallet_balance(100.0)

      find("button#print_slip").click
      expect(page.source).to have_selector("iframe")
      wait_for_ajax
      check_balance_page(@player_balance - 10000)

      audit_log = AuditLog.find_by_audit_target("player_transaction")
      expect(audit_log).to_not eq nil
      expect(audit_log.audit_target).to eq "player_transaction"
      expect(audit_log.action_by).to eq @root_user.name
      expect(audit_log.action_type).to eq "read"
      expect(audit_log.action).to eq "print"
      expect(audit_log.action_status).to eq "success"
      expect(audit_log.action_error).to eq nil
      expect(audit_log.ip).to_not eq nil
      expect(audit_log.session_id).to_not eq nil
      expect(audit_log.description).to_not eq nil
    end

    it '[7.18] Invalid Withdrawal (empty)', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => ''
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq false
      expect(find("label#amount_error").text).to eq I18n.t("invalid_amt.withdraw")
      expect(find("label#type_error").text).to eq I18n.t("invalid_amt.payment_method_type")
      expect(find("label#amount_error")[:style].include?("block")).to eq true
      expect(find("label#type_error")[:style].include?("block")).to eq true
    end

    it '[7.19] Update trans date', :js => true do
      trans_date = (Time.now + 5.second).strftime("%Y-%m-%d %H:%M:%S")
      wallet_response = Requester::WalletTransactionResponse.new({:error_code => 'OK', :error_message => 'Request is carried out successfully.', :trans_date => trans_date})
      allow_any_instance_of(Requester::Wallet).to receive(:withdraw).and_return(wallet_response)
      login_as_admin
      do_withdraw(100)
      transaction = PlayerTransaction.first
      expect(transaction.trans_date).to eq trans_date.to_time(:local).utc
    end

    it '[7.20] Withdraw  success with over limit', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 30000
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(3000000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      content_list = [I18n.t("deposit_withdrawal.exceed_remain_limit")]
      click_pop_up_confirm("confirm_withdraw", content_list) do
        expect(find('label#remain_limit_alert')[:style]).to have_content 'visible'
      end

      check_title("tree_panel.fund_out")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
    end

    it '[7.21] Withdraw, need authorize', :js => true do
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 60000
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(6000000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      expect(find('label#remain_limit_alert')[:style]).to have_content 'visible'
      expect(find('label#authorize_alert')[:style].include?("block")).to eq true
    end
  end

  describe '[52] Enter PIN withdraw success ' do
    before(:each) do
      create_config(:daily_deposit_limit, 25000000)
      create_config(:daily_withdraw_limit, 25000000)
      create_config(:withdraw_authorized_amount, 5000000)
      create_transaction_slip_type('withdraw')
      mock_cage_info
      mock_close_after_print
      mock_patron_not_change
      mock_have_active_location
      @player = create_default_player
      @player_balance = 20000
      mock_wallet_balance(200.0)
      mock_wallet_transaction_success(:withdraw)
    end

    it '[52.1] Enter PIN withdraw success', :js => true do
      allow_any_instance_of(Requester::Patron).to receive(:validate_pin).and_return(Requester::ValidatePinResponse.new({:error_code => 'OK'}))
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      expect(page).to have_selector("div#pop_up_dialog div label#pin_label")
      expect(page).to have_selector("div#pop_up_dialog div label#pin_label")
      expect(page).to have_selector("div#pop_up_dialog div input#player_pin")
      fill_in "player_pin", :with => 1111
      find("div#pop_up_dialog div button#confirm").click
      wait_for_ajax
      expect(first("div div h1").text).to include I18n.t("tree_panel.fund_out")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
    end

    it '[52.2] Enter PIN withdraw fail with wrong PIN', :js => true do
      allow_any_instance_of(Requester::Patron).to receive(:validate_pin).and_raise(Remote::PinError)
      login_as_admin
      go_to_withdraw_page
      fill_in "player_transaction_amount", :with => 100
      find("#player_transaction_payment_method_type option[value='2']").select_option
      find("button#confirm_withdraw").click
      expect(find("div#pop_up_dialog")[:style].include?("block")).to eq true
      expect(find("div#pop_up_dialog")[:class].include?("fadeIn")).to eq true
      expect(find("#fund_amt").text).to eq to_display_amount_str(10000)
      expect(page).to have_selector("div#pop_up_dialog div button#confirm")
      expect(page).to have_selector("div#pop_up_dialog div button#cancel")
      expect(page).to have_selector("div#pop_up_dialog div label#pin_label")
      expect(page).to have_selector("div#pop_up_dialog div label#pin_label")
      expect(page).to have_selector("div#pop_up_dialog div input#player_pin")
      fill_in "player_pin", :with => 1111
      find("div#pop_up_dialog div button#confirm").click
      check_flash_message I18n.t("invalid_pin.invalid_pin")
      check_title("tree_panel.balance")
      # expect(page).to have_selector("table")
      # expect(page).to have_selector("button#print_slip")
      # expect(page).to have_selector("a#close_link")
    end
  end
end
