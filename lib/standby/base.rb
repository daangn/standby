module Standby
  class Base
    def initialize(target, optional: false)
      if optional
        @target = decide_with_optional(target)
      else
        @target = decide_with(target)
      end
    end

    def run(&block)
      run_on @target, &block
    end

    private

    def decide_with(target)
      if Standby.disabled || target == :primary
        :primary
      elsif inside_transaction?
        if target == :optional
          :primary
        else
          raise Standby::Error.new('on_standby cannot be used inside transaction block!')
        end
      elsif target == :null_state || target == :optional
        :standby
      elsif target.present?
        "standby_#{target}".to_sym
      else
        raise Standby::Error.new('on_standby cannot be used with a nil target!')
      end
    end

    def decide_with_optional(target)
      if Standby.disabled || target == :primary || inside_transaction?
        :primary
      elsif target == :null_state
        :standby
      elsif target.present?
        "standby_#{target}".to_sym
      else
        raise Standby::Error.new('on_optional_standby cannot be used with a nil target!')
      end
    end

    def inside_transaction?
      open_transactions = run_on(:primary) { ActiveRecord::Base.connection.open_transactions }
      open_transactions > Standby::Transaction.base_depth
    end

    def run_on(target)
      backup = Thread.current[:_standby] # Save for recursive nested calls
      Thread.current[:_standby] = target
      yield
    ensure
      Thread.current[:_standby] = backup
    end
  end
end
