require "feature_spec_helper"

describe FrontMoneyController do
  before(:all) do
    include Warden::Test::Helpers
    Warden.test_mode!
  end

  after(:all) do
    Warden.test_reset!
  end

  describe '[11] FM Activity Report' do
    before(:each) do
      @player = create_default_player
      @player2 = create_default_player(:last_name => "player2", :member_id => "123457", :card_id => "1234567891")
    end

    it '[11.1] Successfully generate FM Actiivty Report', :js => true do
      login_as_admin
      create_player_transaction
      visit search_front_money_path

      check_search_fm_page

      find("input#search").click
      wait_for_ajax
      transaction_list = [@player_transaction1,@player_transaction2,@player_transaction3]
      check_fm_report_result_items(transaction_list)
    end

    it '[11.2] Search FM Activity Report Unauthorized' do
      login_as_test_user
      set_permission(@test_user,"cashier",:shift,[""])
      visit home_path
      expect(first("aside#left-panel ul li#nav_front_money")).to be_nil
    end

    it '[11.3] FM Activity Report not found' do
      login_as_admin
      visit search_front_money_path

      check_search_fm_page

      find("input#search").click
      expect(find("div.widget-body label").text).to eq t("report_search.no_transaction_found")
    end

    it '[11.4] accounting date cannot be empty', :js => true do
      login_as_admin
      create_player_transaction
      visit search_front_money_path
      #fill_in "accounting_date", :with => 1
      check_search_fm_page

      find("input#search").trigger('click')
      wait_for_ajax
      transaction_list = [@player_transaction1,@player_transaction2,@player_transaction3]
      check_fm_report_result_items(transaction_list)
      expect(find("input#accounting_date").value).to eq AccountingDate.current(@root_user.casino_id).accounting_date.strftime("%Y-%m-%d")
    end

    it '[11.5] only search the casino transaction', :js => true do
      login_as_admin
      create_player_transaction
      #@player_transaction4 = PlayerTransaction.create!(:shift_id => Shift.last.id, :player_id => @player.id, :user_id => User.first.id, :transaction_type_id => 1, :status => "completed", :amount => 40000, :machine_token => '1003|1|LOCATION2|2|STATION1|2|machine2|6e80a295eeff4554bf025098cca6eb38', :created_at => Time.now, :slip_number => 1, :casino_id => 1003)
      visit search_front_money_path

      check_search_fm_page

      find("input#search").click
      wait_for_ajax
      transaction_list = [@player_transaction1,@player_transaction2,@player_transaction3]
      check_fm_report_result_items(transaction_list)
    end
  end

  describe '[17] Print FM Activity Report ' do
    before(:each) do
      @player = create_default_player
      @player2 = create_default_player(:last_name => "player2", :member_id => "123457", :card_id => "1234567891")
    end

    it '[17.2] unauthorized print FM Activity report', :js => true do
      login_as_test_user
      set_permission(@test_user,"cashier",:shift,["search_fm"])
      create_player_transaction
      visit search_front_money_path

      check_search_fm_page

      find("input#search").click
      wait_for_ajax
      transaction_list = [@player_transaction1,@player_transaction2,@player_transaction3]
      check_fm_report_result_items(transaction_list)

      expect(page.source).to_not have_selector("button#print_fm")
    end
  end
end
