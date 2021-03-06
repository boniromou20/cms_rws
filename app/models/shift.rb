class Shift < ActiveRecord::Base
  attr_accessible :shift_type_id, :roll_shift_by_user_id, :roll_shift_on_machine_token, :accounting_date_id, :roll_shift_at, :casino_id
  belongs_to :shift_type

  def name
    ShiftType.get_name_by_id(shift_type_id)
  end

  def accounting_date
    AccountingDate.find_by_id(accounting_date_id).accounting_date
  end

  def roll!(machine_token, user_id)
    raise 'rolled_error' if self.roll_shift_at != nil

    self.machine_token = machine_token
    self.roll_shift_by_user_id = user_id
    self.roll_shift_at = Time.now.utc.change(min: 0).to_formatted_s(:db)
    self.updated_at = Time.now.utc.to_formatted_s(:db)

    new_shift = Shift.new
    new_shift_name = self.class.next_shift_name_by_name(name, self.casino_id)
    new_shift.shift_type_id = ShiftType.get_id_by_name(new_shift_name)
    new_shift.accounting_date_id = AccountingDate.next_shift_accounting_date_id(name, self.casino_id)
    new_shift.casino_id = self.casino_id
    new_shift.created_at = self.roll_shift_at
    new_shift.started_at = Time.now.utc.change(min: 0).to_formatted_s(:db)
    new_shift.updated_at = Time.now.utc.to_formatted_s(:db)
     
    Shift.transaction do
      self.save
      new_shift.save
    end
  end
  
  def manual_roll!(machine_token, user_id)
    raise 'rolled_error' if self.roll_shift_at != nil
    
    shift_num = ConfigHelper.new(self.casino_id).send "roll_shift_time"
    
    self.machine_token = machine_token
    self.roll_shift_by_user_id = user_id
    self.roll_shift_at = self.started_at + (24 / shift_num.split(',').count).hours
    self.updated_at = Time.now.utc.to_formatted_s(:db)

    new_shift = Shift.new
    new_shift_name = self.class.next_shift_name_by_name(name, self.casino_id)
    new_shift.shift_type_id = ShiftType.get_id_by_name(new_shift_name)
    new_shift.accounting_date_id = AccountingDate.next_shift_accounting_date_id(name, self.casino_id)
    new_shift.casino_id = self.casino_id
    new_shift.created_at = self.roll_shift_at
    new_shift.started_at = self.roll_shift_at
    new_shift.updated_at = Time.now.utc.to_formatted_s(:db)
 
    Shift.transaction do
      self.save
      new_shift.save
    end

  end

  class << self
    def get_shift_by_date_and_casino(accounting_date_id, casino_id)
      self.select(:id).find_all_by_accounting_date_id_and_casino_id(accounting_date_id, casino_id)
    end

    def current(casino_id)
      shift = Shift.find_by_roll_shift_at_and_casino_id(nil, casino_id)
      raise "Current shift not found!, casino_id: #{casino_id}" unless shift
      shift
    end

    def next_shift_name_by_name(shift_name, casino_id)
      shift_names = CasinosShiftType.shift_types(casino_id)
      return shift_names[0]if shift_names.index(shift_name).nil?
      shift_names[(shift_names.index(shift_name) + 1) % shift_names.length] 
    end
  end
end
