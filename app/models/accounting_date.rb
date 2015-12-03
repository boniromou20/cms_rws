class AccountingDate < ActiveRecord::Base
  attr_accessible :accounting_date
  has_many :shifts
  include FrontMoneyHelper

  class << self
    def current(property_id)
      self.find_by_id(Shift.current(property_id).accounting_date_id)
    end

    def next_shift_accounting_date_id(shift_name, property_id)
      shift_names = PropertiesShiftType.shift_types(property_id)
      last_shift_name = shift_names[-1]
      if shift_name == last_shift_name
        new_ac_date = new
        new_ac_date.accounting_date = current(property_id).accounting_date + 1
        new_ac_date.save
        new_ac_date.id
      else
        current(property_id).id
      end
    end

    def next_shift_accounting_date(shift_name, current_ac_date, property_id)
      shift_names = PropertiesShiftType.shift_types(property_id)
      last_shift_name = shift_names[-1]
      if shift_name == last_shift_name
        return current_ac_date + 1
      else
        return current_ac_date
      end
    end

    def get_by_date( date )
      accounting_date = self.find_by_accounting_date(date)
      raise FrontMoneyHelper::NoResultException.new "accounting date not exist" if accounting_date.nil?
      accounting_date
    end
  end

end
