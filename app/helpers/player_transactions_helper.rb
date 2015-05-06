module PlayerTransactionsHelper
  def today_start_time
    Time.now.strftime("%d")
  end

  def today_end_time
    Time.parse(today_start_time) + 24*60*60 -1
  end

  def is_close_after_print
    true
  end
end
