require 'net/ldap'
require 'devise/strategies/authenticatable'
require 'user_management'

module Devise
  module Strategies
    class LdapAuthenticatable < Authenticatable
      def valid?
        username || password
      end

      def authenticate!
        result = UserManagement::authenticate(username, password)
        if result['success']
          casino_id = User.get_casino_ids_by_uid(result['system_user']['id']).first
          if Property.find_by_id(casino_id).nil?
            fail!('alert.inactive_account')
            return
          end
          user = User.find_by_uid_and_casino_id(result['system_user']['id'], casino_id)
          if !user
            user = User.create!(:uid => result['system_user']['id'], :name => result['system_user']['username'], :casino_id => casino_id)
          end
          success!(user)
          return
        else
          fail!(result['message'])
          return
        end
      end

      def user_data
        params[:user]
      end

      def username
        if user_data
          return user_data[:username]
        end
        return nil
      end

      def password
        if user_data
          return user_data[:password]
        end
        return nil
      end
    end
  end
end

Warden::Strategies.add(:ldap_authenticatable, Devise::Strategies::LdapAuthenticatable)
