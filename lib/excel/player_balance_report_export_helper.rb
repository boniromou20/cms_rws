module Excel
  class PlayerBalanceReprotExportHelper < ExportHelper
    def generate_export(players, player_balances, total_balances)
      @sheet = @workbook.create_worksheet name: I18n.t("export.player_balance_report")
      write_sheet(players, player_balances, total_balances)
      export
    end

    private

    def write_sheet(players, player_balances, total_balances)
      player_balances = player_balances || {}
      @sheet.row(0).push( I18n.t("general.data_updated_to"), Time.now.strftime("%Y-%m-%d %H:%M:%S"))
      @sheet.row(1).push( I18n.t("general.total_balances"), total_balances)
      titles = [I18n.t("general.member_id"), I18n.t("player.member_status"), I18n.t("player.locked_reasons"), I18n.t("player.cash_balance")]
      write_title(titles, @current_row_number + 2)
      players.each_with_index do |player, index|
        current_number = @current_row_number + 3 + index
        @sheet.row(current_number).default_format = @text_format
        result_array = [
          player.member_id,
          player.status.titleize,
          player.active_lock_types.map{|lock_type| lock_type.name }.join(','),
          player_balances[player.member_id]
        ]
        @sheet.row(current_number).replace result_array
      end
    end
  end
end
