require "../../protocols/modbus_protocol/**"

module Vkt7Driver  
  include Collector
  include ModbusProtocol

  # Driver for VKT-7 thermal meter
  class Driver < CollectorDriver
    include CollectorDriverWithProtocol

    # Execute device task
    def appendTask(deviceTasks : CollectorDeviceTasks) : Void
      
    end
  end
end
