module Collector
  # Device type
  enum DeviceType
    # Self meter
    Meter,
    # Pipe of device
    Pipe,
    # Pipe group of device
    Group
  end

  # Base device info
  abstract class DeviceInfo
  end

  # Base device info
  class MeterDeviceInfo < DeviceInfo
    # Device network number
    getter networkNumber : Int32 = 1
  end

  # Info for passing to protocol driver
  class PipeDeviceInfo < MeterDeviceInfo
    # Pipe number
    getter pipeNumber : Int32

    # Group number
    getter groupNumber : Int32

    def initialize(
      @pipeNumber = 0,
      @groupNumber = 0
    )
      super()
    end
  end

  # Abstract execution context for transfering it between driver and executers
  abstract class BaseExecutionContext
    # Device information
    getter baseDeviceInfo : TDeviceInfo

    # Protocol information
    getter baseProtocol : TProtocol

    def initialize(@deviceInfo, @protocol)
    end
  end

  abstract class ExecutionContext(TDeviceInfo, TProtocol) < BaseExecutionContext
    # Device information
    def deviceInfo : TDeviceInfo
      baseDeviceInfo.as(TDeviceInfo)
    end

    # Protocol information
    def protocol : TProtocol
      baseProtocol.as(TDeviceInfo)
    end

    def initialize(deviceInfo, protocol)
      super(deviceInfo, protocol)
    end
  end

  # Base event
  abstract class CollectorDriverEvent
  end

  # Data value from driver
  alias DataValue = Float64 | Time | String

  # Type of TaskDataEvent
  alias DataTaskValue = DataValue | TimedDataValue
  
  # Value with time
  struct TimedDataValue
    # Date time for value
    getter dateTime : Time

    # Value
    getter value : DataValue

    def initialize(@value, @dateTime)
    end
  end

  # Mixin for response value
  module TaskResponseValue(TValue)
    getter value : TValue
  end
  
  # Event on task
  abstract class DriverTaskResponseEvent < CollectorDriverEvent    
     getter taskId : Int32

     def initialize(@taskId)
     end
  end

  # Event on task with some values from device
  class TaskDataResponseEvent < DriverTaskResponseEvent
    include TaskResponseValue(DataTaskValue)    
    
    def initialize(taskId, @value)
      super(taskId)
    end
 end

  # Response event on time read
  class ReadTimeResponseEvent < DriverTaskResponseEvent    
    include TaskResponseValue(Time) 
    
    def initialize(taskId, @value)
      super(taskId)
    end
  end

  # Timeout
  class DriverTimeoutEvent < CollectorDriverEvent
  end

  # Driver protocol mixin
  module CollectorDriverProtocol(TProtocolType)
    macro included
      class_getter protocol = TProtocolType.new
      def protocol : TProtocolType
        @@protocol
      end     
      
      # Override base protocol
      def baseProtocol : Protocol
        @@protocol
      end
    end
  end

  # Driver executer context mixin
  module CollectorDriverExecuterContext(TExecuterContext)
    # Return executer context
    abstract def executerContext : TExecuterContext    
  end

  # Base collector drver
  abstract class CollectorDriver
    # Device types
    class_property deviceTypes = Set(String).new

    macro registerDevice(deviceType)
      @@deviceTypes.add({{ deviceType }})

      CollectorDriverFactory.register(protocol.class, {{ deviceType }}, {{ @type }})
    end

    # Add tasks for device
    # For override
    abstract def appendTask(deviceTasks : CollectorDeviceTasks) : Void

    def listenBlock!
      @listenBlock.not_nil!
    end

    def listen(&@listenBlock : CollectorDriverEvent -> Void) : Void
    end

    # Notify task event
    def notifyTaskEvent(event : CollectorDriverEvent) : Void
      listenBlock!.call(event)
    end

    # Calc hash
    def hash
      @@deviceTypes.hash ^ protocol.hash
    end

    # Equals
    def ==(other : CollectorDriver)
      hash == other.hash
    end
  end  

  # Base driver for meter
  abstract class CollectorMeterDriver < CollectorDriver    
    # Collector device
    getter device : CollectorDevice?

    # Protocol for working with device
    abstract def baseProtocol : Protocol

    # Execute actions
    private def executeActions(tasks : Array(CollectorActionTask)) : Void
      tasks.each do |task|
        case task.actionInfo.action
        when StateAction::Read
          executeReadAction(task)
        when StateAction::Write
          executeWriteAction(task)
        else
          raise NorthwindException.new("Unknown action")
        end
      end
    end    

    # Execute before all task execution for device
    def executeBefore() : Void
    end

    # Execute after all task execution for device
    def executeAfter() : Void
    end

    # Process read action. Virtual
    def executeReadAction(action : CollectorActionTask) : Void
    end

    # Process write action. Virtual
    def executeWriteAction(action : CollectorActionTask) : Void
    end

    # Process read current values. Virtual
    def executeCurrentValues(tasks : Array(CollectorDataTask)) : Void
    end

    # Process read archive. Virtual
    def executeArchive(tasks : Array(CollectorDataTask)) : Void
    end

    # Execute device task
    def appendTask(deviceTasks : CollectorDeviceTasks) : Void
      @device = deviceTasks.device

      actions = deviceTasks.tasks.compact_map do |x|
        x if x.is_a?(CollectorActionTask)
      end

      current = Array(CollectorDataTask).new
      archive = Array(CollectorDataTask).new

      deviceTasks.tasks.each do |task|        
        case task
        when CollectorDataTask
          if task.parameter.discret.discretType == DiscretType::None
            current << task
          else
            archive << task
          end
        else
        end
      end
      
      executeBefore
      executeActions(actions) if !actions.empty?
      executeCurrentValues(current) if !current.empty?
      executeArchive(archive) if !current.empty?
      executeAfter
    end
  end

  # Base driver task executer
  abstract class CollectorDriverExecuter(TDevice, TProtocol, TResponseType)
    def initialize(@deviceInfo : TDevice, @protocol : TProtocol)      
    end

    def initialize(@deviceInfo : TDevice, @protocol : TProtocol, &block : TResponseType -> Void)
      execute(&block)
    end

    # Execute and iterate values in block
    abstract def execute(&block : TResponseType -> Void)
  end

  # Factory to get driver by Device
  abstract class CollectorDriverFactory
    # Known drivers
    class_property knownDrivers = Hash(Protocol.class, Hash(String, CollectorDriver.class)).new

    # Register device driver
    def self.register(protocolClass : Protocol.class, deviceType : String, driverClass : CollectorDriver.class) : Void
      drivers = knownDrivers[protocolClass]?
      if drivers.nil?
        drivers = Hash(String, CollectorDriver.class).new
        knownDrivers[protocolClass] = drivers
      end

      drivers[deviceType] = driverClass
    end

    # Cache for drivers
    @@driverCache = Hash(Protocol.class, Hash(String, CollectorDriver)).new

    # Get device driver
    def self.get(deviceType : String, protocolType : T.class) : CollectorDriver forall T
      drivers = @@driverCache[protocolType]?
      if drivers
        driver = drivers[deviceType]?
        return driver if !driver.nil?
      end

      drivers = knownDrivers[protocolType]?

      if drivers
        driverClass = drivers[deviceType]?
        if driverClass
          driver = driverClass.new
          cacheDrivers = @@driverCache[protocolType]?
          if cacheDrivers.nil?
            cacheDrivers = Hash(String, CollectorDriver).new
            @@driverCache[protocolType] = cacheDrivers
          end
          cacheDrivers[deviceType] = driver
          return driver
        end
      end

      raise NorthwindException.new("No possible driver can be created for DeviceType: #{deviceType} and ProtocolType: #{protocolType}")
    end
  end
end
