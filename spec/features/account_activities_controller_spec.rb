require "feature_spec_helper"

describe AccountActivitiesController do
  before(:all) do
    include Warden::Test::Helpers
    Warden.test_mode!
  end

  after(:all) do
    Warden.test_reset!
  end

  def create_player_transaction
    machine_token1 = '20000|1|LOCATION1|1|STATION1|1|machine1|6e80a295eeff4554bf025098cca6eb37'
    PlayerTransaction.create!(:shift_id => Shift.last.id, :player_id => @player.id, :transaction_type_id => 1, :status => "completed", :amount => 10000, :machine_token => machine_token1, :created_at => Time.now, :slip_number => 1, :ref_trans_id => 'C00000001', :casino_id => 20000)
  end

  def mock_transactions(trans_type = 'deposit', ref_trans_id = 'C000000EE')
    [{'player_id' => @player.id, 'cash_before_balance' => 190000.12, 'cash_after_balance' => 185000.12, 'cash_amt' => -5000.12, 'credit_before_balance' => 100.00, 'credit_after_balance' => 50.00, 'credit_amt' => 50.00, 'ref_trans_id' => ref_trans_id, 'trans_type' => trans_type, 'trans_date' => Time.parse('2017-12-12 10:15:27'), 'round_id' => '123456', 'property_id' => 20000, 'property_name' => 'MockUp', 'status' => 'completed', 'casino_id' => 20000, 'casino_name' => 'MockUp', 'employee_name' => 'portal.admin', 'machine_token' => '20000|1|LOCATION1|1|STATION1|1|machine1|6e80a295eeff4554bf025098cca6eb37'}]
  end

  def check_account_activity_data(trans, player_trans = nil)
    trans = trans.symbolize_keys
    values = [trans[:trans_date].strftime("%Y-%m-%d %H:%M:%S"), trans[:trans_type].titleize, trans[:casino_name], trans[:property_name], 'LOCATION1/STATION1', trans[:ref_trans_id], trans[:round_id], player_trans.try(:slip_number), trans[:employee_name], trans[:status], display_balance(trans[:cash_before_balance]), display_balance(trans[:credit_before_balance]), display_balance(trans[:cash_amt]), display_balance(trans[:credit_amt]),display_balance(trans[:cash_after_balance]), display_balance(trans[:credit_after_balance])]
    within('div#content table#account_activity_datatable tbody tr:nth-child(1)') do
      values.each_with_index do |td, td_index|
        expect(find("td:nth-child(#{td_index+1})").text).to eq td.to_s
      end
    end
  end

  # describe 'Search Account Activity by Member', js: true do
  #   before(:each) do
  #     mock_cage_info
  #     mock_patron_not_change
  #     @player = create_default_player
  #   end

  #   it 'show account activity page' do
  #     mock_account_activities
  #     login_as_admin
  #     go_to_account_activity_page
  #   end

  #   it 'show account activity data' do
  #     player_trans = create_player_transaction
  #     transactions = mock_transactions('deposit', player_trans.ref_trans_id)
  #     mock_account_activities(transactions)
  #     login_as_admin
  #     go_to_account_activity_page
  #     check_account_activity_data(transactions[0], player_trans)
  #   end

  #   it 'show account activity failed: member_id is empty' do
  #     login_as_admin
  #     go_to_account_activity_page(nil, false)
  #     check_flash_message I18n.t('transaction_history.no_id')
  #   end

  #   it 'show account activity failed: search player error' do
  #     mock_player_info_result({:error_code => 'error'})
  #     login_as_admin
  #     go_to_account_activity_page('1111', false)
  #     check_flash_message I18n.t('search_error.not_found')
  #   end

  #   it 'show account activity failed: get_account_activity error' do
  #     mock_account_activities_failed
  #     login_as_admin
  #     go_to_account_activity_page
  #     expect(find('table#account_activity_datatable')).to have_content I18n.t('account_activity.search_error')
  #   end

  #   it 'unauthorized account activity' do
  #     login_as_test_user
  #     visit home_path
  #     expect(first("aside#left-panel ul li#nav_account_activity")).to eq nil
  #   end
  # end

  # describe 'Search Account Activity by Round', js: true do
  #   before(:each) do
  #     mock_cage_info
  #     mock_patron_not_change
  #     @player = create_default_player
  #   end

  #   it 'show account activity page without transactions' do
  #     mock_account_activities
  #     login_as_admin
  #     go_to_account_activity_page(nil, false, '123456', 1)
  #   end

  #   it 'show account activity page with player info' do
  #     transactions = mock_transactions('bet')
  #     mock_account_activities(transactions)
  #     login_as_admin
  #     go_to_account_activity_page(nil, true, '123456', 1)
  #     check_account_activity_data(transactions[0])
  #   end

  #   it 'show account activity failed: round_id is empty' do
  #     login_as_admin
  #     go_to_account_activity_page(nil, false, nil, 1)
  #     check_flash_message I18n.t('account_activity.no_round_id')
  #   end

  #   it 'show account activity failed: get_account_activity error' do
  #     mock_account_activities_failed
  #     login_as_admin
  #     go_to_account_activity_page(nil, false, '123456', 1)
  #     expect(find('table#account_activity_datatable')).to have_content I18n.t('account_activity.search_error')
  #   end
  # end
end
