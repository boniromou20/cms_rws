require "feature_spec_helper"

describe FundInController do
  before(:all) do
    include Warden::Test::Helpers
    Warden.test_mode!
    PlayerTransaction.delete_all
    User.delete_all
    @root_user = User.create!(:uid => 1, :employee_id => 'portal.admin')
  end

  after(:all) do
    PlayerTransaction.delete_all
    User.delete_all
    Warden.test_reset!
  end

  describe '[6] Deposit' do
    before(:each) do
      AuditLog.delete_all
      PlayerTransaction.delete_all
      Player.delete_all
      @player = Player.create!(:player_name => "test", :member_id => "123456", :currency_id => 1,:balance => 0, :status => "unlock")
      TransactionType.create!(:name => "Deposit")
    end
    
    after(:each) do
      AuditLog.delete_all
      PlayerTransaction.delete_all
      Player.delete_all
    end

    it '[6.1] show Deposit page' do
      login_as(@root_user)
      visit home_path
      click_link I18n.t("tree_panel.balance")
      fill_in "player_member_id", :with => @player.member_id
      click_button I18n.t("button.find")
      check_title("tree_panel.balance")

      within "div#content" do
        click_link I18n.t("button.deposit")
      end
      check_title("tree_panel.fund_in")
      expect(find("label#player_name").text).to eq @player.player_name
      expect(find("label#player_member_id").text).to eq @player.member_id.to_s
      expect(page.source).to have_selector("button#confirm")
      expect(page.source).to have_selector("button#cancel")
    end
    
    it '[6.2] Invalid Deposit', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 0.111
      expect(find("input#player_transaction_amount").value).to eq "0.11"
    end

    it '[6.3] Invalid Deposit(eng)', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => "abc3de"
      expect(find("input#player_transaction_amount").value).to eq ""
    end

    it '[6.4] Invalid Deposit (input 0 amount)', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 0
      click_button I18n.t("button.confirm")
      find("div#confirm_fund_dialog")[:style].include?("block").should == true
      find("div#confirm_fund_dialog div button#confirm").click
      check_title("tree_panel.fund_in")
      expect(find("label#player_name").text).to eq @player.player_name
      expect(find("label#player_member_id").text).to eq @player.member_id.to_s
      check_flash_message I18n.t("invalid_amt.deposit")
    end

    it '[6.5] cancel Deposit' do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      find("div#button_set form input#cancel").click

      check_title("tree_panel.home")
    end

    it '[6.6] Confirm Deposit', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      find("div#confirm_fund_dialog")[:style].include?("block").should == true
      find("div#button_set button#confirm")[:disabled].should == "disabled"
      find("div#button_set form input#cancel")[:disabled].should == "disabled"
      expect(find("#fund_amt").text).to eq "100"
      expect(page).to have_selector("div#confirm_fund_dialog div button#confirm")
      expect(page).to have_selector("div#confirm_fund_dialog div button#cancel")
    end

    it '[6.7] cancel dialog box Deposit', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      find("div#confirm_fund_dialog")[:style].include?("block").should == true
      find("div#button_set button#confirm")[:disabled].should == "disabled"
      find("div#button_set form input#cancel")[:disabled].should == "disabled"
      expect(find("#fund_amt").text).to eq "100"
      expect(page).to have_selector("div#confirm_fund_dialog div button#confirm")
      expect(page).to have_selector("div#confirm_fund_dialog div button#cancel")
      find("div#confirm_fund_dialog div button#cancel").click
      find("div#confirm_fund_dialog")[:style].include?("none").should == true
      find("div#button_set button#confirm")[:disabled].should be_nil
      find("div#button_set form input#cancel")[:disabled].should be_nil
    end


    it '[6.8] Confirm Deposit', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      expect(find("div#confirm_fund_dialog")[:style].include?("block")).to eq true
      find("div#button_set button#confirm")[:disabled].should == "disabled"
      find("div#button_set form input#cancel")[:disabled].should == "disabled"
      expect(find("#fund_amt").text).to eq "100"
      expect(page).to have_selector("div#confirm_fund_dialog div button#confirm")
      expect(page).to have_selector("div#confirm_fund_dialog div button#cancel")
      find("div#confirm_fund_dialog div button#confirm").click
      
      check_title("tree_panel.fund_in")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
    end

    it '[6.9] audit log for confirm dialog box Deposit', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=" + @player.member_id
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      find("div#confirm_fund_dialog div button#confirm").click
      wait_for_ajax
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
      
      audit_log = AuditLog.find_by_audit_target("player")
      audit_log.should_not be_nil
      audit_log.audit_target.should == "player"
      audit_log.action_by.should == @root_user.employee_id
      audit_log.action_type.should == "update"
      audit_log.action.should == "deposit"
      audit_log.action_status.should == "success"
      audit_log.action_error.should be_nil
      audit_log.ip.should_not be_nil
      audit_log.session_id.should_not be_nil
      audit_log.description.should_not be_nil
    end

    it '[6.10] click unauthorized action (Deposit)' do
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,["balance"])
      set_permission(@test_user,"cashier",:player_transaction,["deposit"])
      visit home_path
      click_link I18n.t("tree_panel.balance")
      fill_in "player_member_id", :with => @player.member_id
      click_button I18n.t("button.find")
      
      expect(find("label#player_name").text).to eq @player.player_name
      expect(find("label#player_member_id").text).to eq @player.member_id.to_s
      expect(find("label#player_balance").text).to eq to_display_amount_str(@player.balance)
      set_permission(@test_user,"cashier",:player,[])
      set_permission(@test_user,"cashier",:player_transaction,[])

      find("div a#balance_deposit").click

      check_title("tree_panel.home")
      check_flash_message I18n.t("flash_message.not_authorize")
    end

    it '[6.11] click link to the unauthorized page' do
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player_transaction,[])
      visit fund_in_path + "?member_id=#{@player.member_id}"
      check_title("tree_panel.home")
      check_flash_message I18n.t("flash_message.not_authorize")
    end

    it '[6.12] click unauthorized action (confirm dialog box Deposit)', :js => true do
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,["balance"])
      set_permission(@test_user,"cashier",:player_transaction,["deposit"])
      visit fund_in_path + "?member_id=" + @player.member_id
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      set_permission(@test_user,"cashier",:player_transaction,[])
      find("div#confirm_fund_dialog div button#confirm").click
      wait_for_ajax

      check_title("tree_panel.home")
      check_flash_message I18n.t("flash_message.not_authorize")
    end
    
    it '[6.13] click unauthorized action (print slip)', :js => true do
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player_transaction,["deposit"])
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      expect(find("div#confirm_fund_dialog")[:style].include?("block")).to eq true
      find("div#button_set button#confirm")[:disabled].should == "disabled"
      find("div#button_set form input#cancel")[:disabled].should == "disabled"
      expect(find("#fund_amt").text).to eq "100"
      expect(page).to have_selector("div#confirm_fund_dialog div button#confirm")
      expect(page).to have_selector("div#confirm_fund_dialog div button#cancel")
      find("div#confirm_fund_dialog div button#confirm").click
      
      check_title("tree_panel.fund_in")
      expect(page).to have_selector("table")
      expect(page).to_not have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
    end

    it '[6.14] Confirm Deposit', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      expect(find("div#confirm_fund_dialog")[:style].include?("block")).to eq true
      find("div#button_set button#confirm")[:disabled].should == "disabled"
      find("div#button_set form input#cancel")[:disabled].should == "disabled"
      expect(find("#fund_amt").text).to eq "100"
      expect(page).to have_selector("div#confirm_fund_dialog div button#confirm")
      expect(page).to have_selector("div#confirm_fund_dialog div button#cancel")
      find("div#confirm_fund_dialog div button#confirm").click
      
      check_title("tree_panel.fund_in")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")

      find("button#print_slip").click
      expect(page.driver.browser.window_handles.length).to eq 1
      new_window = page.driver.browser.window_handles.last do |page|
        page.driver.browser.switch_to.window(page)
        page.execute_script "window.close()"
      end
      wait_for_ajax
      check_title("tree_panel.home")
    end

    it '[6.15] Close slip', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      expect(find("div#confirm_fund_dialog")[:style].include?("block")).to eq true
      find("div#button_set button#confirm")[:disabled].should == "disabled"
      find("div#button_set form input#cancel")[:disabled].should == "disabled"
      expect(find("#fund_amt").text).to eq "100"
      expect(page).to have_selector("div#confirm_fund_dialog div button#confirm")
      expect(page).to have_selector("div#confirm_fund_dialog div button#cancel")
      find("div#confirm_fund_dialog div button#confirm").click
      
      check_title("tree_panel.fund_in")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
      
      find("a#close_link").click
      wait_for_ajax
      check_title("tree_panel.home")
    end
    
    it '[6.16] audit log for print slip', :js => true do
      login_as(@root_user) 
      visit fund_in_path + "?member_id=#{@player.member_id}"
      fill_in "player_transaction_amount", :with => 100
      click_button I18n.t("button.confirm")
      expect(find("div#confirm_fund_dialog")[:style].include?("block")).to eq true
      find("div#button_set button#confirm")[:disabled].should == "disabled"
      find("div#button_set form input#cancel")[:disabled].should == "disabled"
      expect(find("#fund_amt").text).to eq "100"
      expect(page).to have_selector("div#confirm_fund_dialog div button#confirm")
      expect(page).to have_selector("div#confirm_fund_dialog div button#cancel")
      find("div#confirm_fund_dialog div button#confirm").click
      
      check_title("tree_panel.fund_in")
      expect(page).to have_selector("table")
      expect(page).to have_selector("button#print_slip")
      expect(page).to have_selector("a#close_link")
      
      find("button#print_slip").click
      expect(page.driver.browser.window_handles.length).to eq 1
      new_window = page.driver.browser.window_handles.last do |page|
        page.driver.browser.switch_to.window(page)
        page.execute_script "window.close()"
      end
      wait_for_ajax
      check_title("tree_panel.home")
      
      audit_log = AuditLog.find_by_audit_target("player_transaction")
      audit_log.should_not be_nil
      audit_log.audit_target.should == "player_transaction"
      audit_log.action_by.should == @root_user.employee_id
      audit_log.action_type.should == "read"
      audit_log.action.should == "print"
      audit_log.action_status.should == "success"
      audit_log.action_error.should be_nil
      audit_log.ip.should_not be_nil
      audit_log.session_id.should_not be_nil
      audit_log.description.should_not be_nil
    end
  end
end