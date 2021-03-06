module CageInfoHelper
  def update_accounting_date_interval
    polling_interval
  end

  def update_shift_interval
    polling_interval
  end

  def default_shift_widget_message
    "Waiting for shift"
  end

  def default_accounting_date_widget_message
    "Waiting for accounting date"
  end

  def default_location_widget_message
    "---"
  end

  def default_casino_widget_message
    "---"
  end

protected

  def polling_interval
    #milliseconds

    if @config_helper && @config_helper.polling_time != 0 
      polling_time =  @config_helper.polling_time
    else
      polling_time = 60 * 1000 
    end
    polling_time + rand(1..500)

  end
end
