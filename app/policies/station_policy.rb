class StationPolicy < ApplicationPolicy
  
  def list?
    return true
  end

  def create?
    return true
  end
  
  def change_status?
  return true
  end

end
