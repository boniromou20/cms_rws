module FundHelper
  def amount_valid?( amount )
    return false unless amount.is_a? String
    return false unless amount =~ /^\d+(\.\d{1,2})?$/
    return false unless to_server_amount( amount ) > 0
    true
  end

  def to_server_amount( amount )
    (amount.to_f.round(2) * 100).to_i
  end

  def to_display_amount_str( amount )
    "%0.2f" % (amount.to_f / 100)
  end
end
