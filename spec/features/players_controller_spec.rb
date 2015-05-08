require "feature_spec_helper"

describe PlayersController do
  before(:all) do
    include Warden::Test::Helpers
    Warden.test_mode!
    PlayerTransaction.delete_all
    @root_user = User.create!(:uid => 1, :employee_id => 'portal.admin')
  end

  after(:all) do
    PlayerTransaction.delete_all
    User.delete_all
    Warden.test_reset!
  end

  describe '[3] Create player' do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info
    end

    after(:each) do
      AuditLog.delete_all
      Player.delete_all
    end

    it '[3.1] Show Create Player Page' do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.create_player")
      check_title("tree_panel.create_player")
      expect(page.source).to have_selector("form#new_player input#player_member_id")
      expect(page.source).to have_selector("form#new_player input#player_player_name")
    end

    it '[3.2] Successfully create player' do
      login_as_admin
      visit new_player_path
      @player = Player.new
      @player.card_id = 1234567890
      @player.member_id = 123456
      @player.player_name = "test player"
      fill_in "player_card_id", :with => @player.card_id
      fill_in "player_member_id", :with => @player.member_id
      fill_in "player_player_name", :with => @player.player_name
      click_button I18n.t("button.create")

      check_title("tree_panel.balance")
      check_flash_message I18n.t("create_player.success")

      test_player = Player.find_by_member_id(@player.member_id)
      expect(test_player).not_to be_nil
      test_player.card_id = @player.card_id
      test_player.member_id = @player.member_id
      test_player.player_name = @player.player_name
    end

    it '[3.3] player already exist' do
      Player.create!(:player_name => "exist", :member_id => 123456, :currency_id => 1, :balance => 0, :status => "active")
      login_as_admin
      visit new_player_path
      @player = Player.new
      @player.card_id = 1234567890
      @player.member_id = 123456
      @player.player_name = "test player"
      fill_in "player_card_id", :with => @player.card_id
      fill_in "player_member_id", :with => @player.member_id
      fill_in "player_player_name", :with => @player.player_name
      click_button I18n.t("button.create")

      check_title("tree_panel.create_player")
      check_flash_message I18n.t("create_player.exist")
    end

    it '[3.4] empty membership ID' do
      login_as_admin
      visit new_player_path
      @player = Player.new
      @player.card_id = 1234567890
      @player.member_id = 123456
      @player.player_name = "test player"
      fill_in "player_card_id", :with => @player.card_id
      fill_in "player_player_name", :with => @player.player_name
      click_button I18n.t("button.create")

      check_title("tree_panel.create_player")
      check_flash_message I18n.t("create_player.member_id_blank_error")
    end

    it '[3.5] empty Player name' do
      login_as_admin
      visit new_player_path
      @player = Player.new
      @player.card_id = 1234567890
      @player.member_id = 123456
      @player.player_name = "test player"
      fill_in "player_card_id", :with => @player.card_id
      fill_in "player_member_id", :with => @player.member_id
      click_button I18n.t("button.create")

      check_title("tree_panel.create_player")
      check_flash_message I18n.t("create_player.name_blank_error")
    end

    it '[3.6] Audit log for successful create player' do
      login_as_admin
      visit new_player_path
      @player = Player.new
      @player.card_id = 1234567890
      @player.member_id = 123456
      @player.player_name = "test player"
      fill_in "player_card_id", :with => @player.card_id
      fill_in "player_member_id", :with => @player.member_id
      fill_in "player_player_name", :with => @player.player_name
      click_button I18n.t("button.create")

      audit_log = AuditLog.find_by_audit_target("player")
      audit_log.should_not be_nil
      audit_log.audit_target.should == "player"
      audit_log.action_by.should == @root_user.employee_id
      audit_log.action_type.should == "create"
      audit_log.action.should == "create"
      audit_log.action_status.should == "success"
      audit_log.action_error.should be_nil
      audit_log.ip.should_not be_nil
      audit_log.session_id.should_not be_nil
      audit_log.description.should_not be_nil
    end

    it '[3.7] Audit log for fail create player' do
      Player.create!(:player_name => "exist", :member_id => 123456, :currency_id => 1, :balance => 0, :status => "active")
      login_as_admin
      visit new_player_path
      @player = Player.new
      @player.card_id = 1234567890
      @player.member_id = 123456
      @player.player_name = "test player"
      fill_in "player_card_id", :with => @player.card_id
      fill_in "player_member_id", :with => @player.member_id
      fill_in "player_player_name", :with => @player.player_name
      click_button I18n.t("button.create")

      audit_log = AuditLog.find_by_audit_target("player")
      audit_log.should_not be_nil
      audit_log.audit_target.should == "player"
      audit_log.action_by.should == @root_user.employee_id
      audit_log.action_type.should == "create"
      audit_log.action.should == "create"
      audit_log.action_status.should == "fail"
      audit_log.action_error.should_not be_nil
      audit_log.ip.should_not be_nil
      audit_log.session_id.should_not be_nil
      audit_log.description.should_not be_nil
    end

    it '[3.8] click unauthorized action', js: true do 
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,["create"])
      visit home_path
      set_permission(@test_user,"cashier",:player,[])
      click_link I18n.t("tree_panel.create_player")
      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end     
    
    it '[3.9] click link to the unauthorized page', js: true do 
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,[])
      visit new_player_path
      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end     
    
    it '[3.10] unauthorization for create player', js: true do 
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,[])
      visit home_path
      first("aside#left-panel ul li#nav_create_player").should be_nil
    end     

    it '[3.11] empty card ID' do
      login_as_admin
      visit new_player_path
      @player = Player.new
      @player.card_id = 1234567890
      @player.member_id = 123456
      @player.player_name = "test player"
      fill_in "player_member_id", :with => @player.member_id
      fill_in "player_player_name", :with => @player.player_name
      click_button I18n.t("button.create")

      check_title("tree_panel.create_player")
      check_flash_message I18n.t("create_player.card_id_blank_error")
    end

    it '[3.12] member id and card ID can only input number' do
      login_as_admin
      visit new_player_path
      fill_in "player_card_id", :with => '..//.-=-++-'
      fill_in "player_member_id", :with => '123456'
      fill_in "player_player_name", :with => '$$$$@@@'
      click_button I18n.t("button.create")

      check_title("tree_panel.create_player")
      check_flash_message I18n.t("create_player.card_id_only_number_allowed_error")
      
      fill_in "player_card_id", :with => '1234567890'
      fill_in "player_member_id", :with => 'hahaha'
      fill_in "player_player_name", :with => '$$$$@@@'
      click_button I18n.t("button.create")

      check_title("tree_panel.create_player")
      check_flash_message I18n.t("create_player.member_id_only_number_allowed_error")
    end
  end
  
  describe '[4] Search player by membership ID' do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info
    end

    after(:each) do
      Player.delete_all
    end

    it '[4.1] Show search Page' do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.balance")
      check_search_page
    end

    it '[4.2] successfully search player' do
      @player = Player.create!(:player_name => "exist", :member_id => 123456, :card_id => 1234567890, :currency_id => 1, :balance => 0, :status => "active")
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      check_balance_page
      check_player_info
    end
    
    it '[4.3] fail to search player' do
      @player = Player.new
      @player.member_id = 123456
      @player.player_name = "test player"
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      check_not_found
      click_link I18n.t("button.create")
    end
    
    it '[4.4] direct to create player' do
      @player = Player.new
      @player.member_id = 123456
      @player.player_name = "test player"
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      check_not_found
      click_link I18n.t("button.create")
      check_title("tree_panel.create_player")
      expect(find("form#new_player input#player_member_id").value).to eq @player.member_id.to_s
    end
  end
  
  describe '[5] Balance Enquiry' do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info
    end

    after(:each) do
      Player.delete_all
    end

    it '[5.1] view player balance enquiry' do
      @player = Player.create!(:player_name => "exist", :member_id => 123456, :card_id => 1234567890, :currency_id => 1, :balance => 9999, :status => "active")
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.balance")
      check_search_page
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      
      check_player_info
      check_balance_page

      expect(page.source).to have_selector("div a#balance_deposit")
      expect(page.source).to have_selector("div a#balance_withdraw")
      expect(page.source).to have_selector("div a#balance_close")
    end

    it '[5.2] click unauthorized action', :js => true do 
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,["balance"])
      visit home_path
      set_permission(@test_user,"cashier",:player,[])
      click_link I18n.t("tree_panel.balance")
      wait_for_ajax
      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end     
    
    it '[5.3] click link to the unauthorized page', :js => true do 
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,[])
      visit balance_path
      wait_for_ajax
      check_home_page
      check_flash_message I18n.t("flash_message.not_authorize")
    end     
    
    it '[5.4] authorized to search and unauthorized to create' do 
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,["balance"])
      visit players_search_path + "?operation=balance"
      fill_search_info("member_id", 123456)

      find("#button_find").click
      check_not_found
      expect(page.source).to_not have_content(I18n.t("search_error.create_player"))
    end     
    
    it '[5.5] Return to Cage home' do
      @player = Player.create!(:player_name => "exist", :member_id => 123456, :card_id => 1234567890, :currency_id => 1, :balance => 9999, :status => "active")
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.balance")
      check_search_page
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click
      
      check_balance_page
      check_player_info
      
      expect(page.source).to have_selector("div a#balance_deposit")
      expect(page.source).to have_selector("div a#balance_withdraw")
      expect(page.source).to have_selector("div a#balance_close")

      find("div a#balance_close").click
      expect(page).to have_content @location
      expect(page).to have_content "Waiting for accounting date"
      expect(page).to have_content "Waiting for shift"
    end

    it '[5.6] unauthorized to all actions' do
      @player = Player.create!(:player_name => "exist", :member_id => 123456, :card_id => 1234567890, :currency_id => 1, :balance => 9999, :status => "active")
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,["balance"])
      set_permission(@test_user,"cashier",:player_transaction,[])
      visit home_path
      click_link I18n.t("tree_panel.balance")
      check_search_page
      fill_search_info("member_id", @player.member_id)
      find("#button_find").click

      check_balance_page
      check_player_info
      
      expect(page.source).to_not have_selector("div a#balance_deposit")
      expect(page.source).to_not have_selector("div a#balance_withdraw")
      expect(page.source).to have_selector("div a#balance_close")
    end
    
    it '[5.7] unathorized to balance enquriy ' do 
      @test_user = User.create!(:uid => 2, :employee_id => 'test.user')
      login_as_not_admin(@test_user)
      set_permission(@test_user,"cashier",:player,[])
      visit home_path
      first("aside#left-panel ul li#nav_balance_enquiry").should be_nil
    end     
  end
  
  describe '[12] Search player by card ID' do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info
    end

    after(:each) do
      Player.delete_all
    end

    it '[12.1] Show search Page' do
      login_as_admin
      visit home_path
      click_link I18n.t("tree_panel.balance")
      check_search_page
    end

    it '[12.2] successfully search player' do
      @player = Player.create!(:player_name => "exist", :member_id => 123456, :card_id => 1234567890, :currency_id => 1, :balance => 0, :status => "active")
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("card_id", @player.card_id)
      find("#button_find").click
      check_balance_page
      check_player_info
    end
    
    it '[12.3] fail to search player' do
      @player = Player.new
      @player.member_id = 123456
      @player.card_id = 1234567890
      @player.player_name = "test player"
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info("card_id", @player.card_id)
      find("#button_find").click
      check_not_found
      click_link I18n.t("button.create")
    end
    
    it '[12.4] direct to create player', :js => true do
      @player = Player.new
      @player.member_id = 123456
      @player.card_id = 1234567890
      @player.player_name = "test player"
      login_as_admin
      visit players_search_path + "?operation=balance"
      fill_search_info_js("card_id", @player.card_id)
      find("#button_find").click
      wait_for_ajax
      check_not_found
      click_link I18n.t("button.create")
      wait_for_ajax
      check_title("tree_panel.create_player")
      expect(find("form#new_player input#player_card_id").value).to eq @player.card_id.to_s
    end
  end
end
