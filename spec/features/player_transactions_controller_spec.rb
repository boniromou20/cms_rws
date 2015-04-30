require "feature_spec_helper"

describe PlayersController do
  before(:all) do
    include Warden::Test::Helpers
    Warden.test_mode!
    @root_user = User.create!(:uid => 1, :employee_id => 'portal.admin')
  end

  after(:all) do
    Warden.test_reset!
  end

  describe '[8] Transaction History report' do
    before(:each) do
      clean_dbs
      create_shift_data
      mock_cage_info
      @player = Player.create!(:player_name => "test", :member_id => "123456", :card_id => "1234567890", :currency_id => 1,:balance => 0, :status => "active")
      @player2 = Player.create!(:player_name => "test2", :member_id => "123457", :card_id => "1234567891", :currency_id => 1,:balance => 100, :status => "active")
    end

    after(:each) do
      PlayerTransaction.delete_all
    end

    it '[8.1] successfully generate report. (search by card ID)' do
      login_as_admin
      @player_transaction1 = PlayerTransaction.create!(:shift_id => Shift.last.id, :player_id => @player.id, :user_id => User.first.id, :transaction_type_id => 1, :status => "complete", :amount => 10000, :station_id => @station_id, :created_at => Time.now)
      visit home_path
      click_link I18n.t("tree_panel.balance")
      fill_search_info("member_id", @player.member_id)
      click_button I18n.t("button.find")
      check_balance_page

      within "div#content" do
        click_link I18n.t("tree_panel.player_transaction")
      end
      
      check_player_transaction_page
      expect(find("input#id_number").value).to eq @player.card_id

      find("input#search").click
      transaction_item = all("tr#transaction_#{@player_transaction1.id} td")
      check_player_transaction_result_contents(transaction_item, @player_transaction1)
    end

    it '[8.2] successfully generate report. (search by time)' do
      login_as_admin
      @player_transaction1 = PlayerTransaction.create!(:shift_id => Shift.last.id, :player_id => @player.id, :user_id => User.first.id, :transaction_type_id => 1, :status => "complete", :amount => 10000, :station_id => @station_id, :created_at => Time.now)
      @player_transaction2 = PlayerTransaction.create!(:shift_id => Shift.last.id, :player_id => @player.id, :user_id => User.first.id, :transaction_type_id => 1, :status => "complete", :amount => 20000, :station_id => @station_id, :created_at => Time.now + 30*60)
      @player_transaction3 = PlayerTransaction.create!(:shift_id => Shift.last.id, :player_id => @player.id, :user_id => User.first.id, :transaction_type_id => 1, :status => "complete", :amount => 30000, :station_id => @station_id, :created_at => Time.now + 60*60)

      visit search_transactions_path
      check_player_transaction_page
      fill_in "datetimepicker_start_time", :with => (Time.now + 20*60)
      find("input#search").click

      transaction_items = all("table#datatable_col_reorder tr")
      p "transaction_items",transaction_items

      check_player_transaction_result_items(transaction_items, [@player_transaction2,@player_transaction3])
    end



  end
end
