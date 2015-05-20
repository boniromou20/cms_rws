class AuditLog < ActiveRecord::Base
  attr_accessible :action, :action_by, :action_error, :action_status, :action_type, :audit_target, :description, :ip, :session_id

  ACTION_MENU = {:all => { :all => "general.all" },
                 :maintenance => { :all => "general.all",
                                   :create => "maintenance_action.create", 
                                   :cancel => "maintenance_action.cancel", 
                                   :complete => "maintenance_action.complete", 
                                   :extend => "maintenance_action.extend", 
                                   :reschedule => "maintenance_action.reschedule", 
                                   :expire => "maintenance_action.expire" },
                 :propagation => { :all => "general.all", :resume => "propagation.resume" },
                 :test_player => { :all => "general.all", 
                                   :add => "test_player.add", 
                                   :enable => "test_player.enable", 
                                   :disable => "test_player.disable", 
                                   :deprecate => "test_player.deprecate", 
                                   :recover => "test_player.recover", 
                                   :sync => "test_player.sync" }}
  ACTION_TYPE_LIST = { 
    :player => {:create => "create",:deposit => "update", :withdrawal => "update", :edit => "update"},
    :player_transaction => {:print => "read"},
    :shift => {:roll_shift => "create"}
  }

  def self.player_log(action, action_by, ip, session_id, options={}, &block)
    compose_log(action, action_by, "player", ip, session_id, options, &block)
  end

  def self.fund_in_out_log(action, action_by, ip, session_id, options={}, &block)
    compose_log(action, action_by, "player", ip, session_id, options, &block)
  end

  def self.print_log(action, action_by, ip, session_id, options={}, &block)
    compose_log(action, action_by, "player_transaction", ip, session_id, options, &block)
  end

  def self.shift_log(action, action_by, ip, session_id, options={}, &block)
    compose_log(action, action_by, "shift", ip, session_id, options, &block)
  end

  private
  def self.compose_log(action, action_by, audit_target, ip, session_id, options={}, &block)
    content = options.merge({:action => action, :action_by => action_by, :audit_target => audit_target, :ip => ip, :session_id => session_id})
    begin
      block.call if block
      logging(content)
    rescue Exception => e
      unless e.class == ArgumentError
        logging(content.merge({:action_error => e.message, :action_status => "fail"}))
      end
      raise e
    end
  end

  def self.logging(content={})
    action = content[:action]
    action_by = content[:action_by]
    action_error = content[:action_error]
    action_status = content[:action_status] || "success"
    audit_target = content[:audit_target]
    action_type = content[:action_type] || ACTION_TYPE_LIST[audit_target.to_sym][action.to_sym]
    description = content[:description]
    ip = content[:ip]
    session_id = content[:session_id]
    content_to_insert = {:action => action, :action_by => action_by, :action_error => action_error, :action_status => action_status, :action_type => action_type, :audit_target => audit_target, :description => description, :ip => ip, :session_id => session_id}
    self.create!(content_to_insert)
    Rails.logger.info "[AuditLogs] capture an action and created a log with content=#{content_to_insert.inspect}"
  end
end
