require "./database/*"

module Collector
  # Info about completion
  class ScriptCompleteInfo
    # Execution time
    getter executeTime : Time::Span

    def initialize(@executeTime)
    end
  end

  # Info about task. Used to process driver answer
  private struct ScriptTaskInfo
    # Device
    getter device : CollectorDevice

    # Task
    getter task : CollectorTask

    def initialize(@device, @task)
    end
  end

  # Collector script
  class CollectorScript
    include Database
    # include Device

    # Period of timer to check schedule
    PERIOD = 10

    # Deep of collect in days
    DEFAULT_DEEP = 3

    # Driver no any event timeout
    # Guards from driver hangs
    DRIVER_SILENCE_TIMEOUT = 1 * 60

    # Collector context
    @collectorWorker : CollectorWorkerContext

    # For working with data
    @database : Database::DatabaseClient

    # Schedule of script
    @schedule : Schedule

    # Devices to request
    @devices : Set(CollectorDevice)

    # Parameters to collect
    @parameters : Set(MeasureParameter)

    # Actions
    @actions : Set(DeviceAction)

    # To notify script execution completed
    @executeCompleter : Completer(ScriptCompleteInfo)?

    def executeCompleter!
      @executeCompleter.not_nil!
    end

    # Deep of requests
    property deep : Int32 = DEFAULT_DEEP

    # Is script working
    getter isWorking : Bool = false

    # Name of script
    getter name : String

    # Process device action event
    private def processActionEvent(device : CollectorDevice, task : CollectorActionTask, event : DriverTaskResponseEvent) : Void      
      parameter = EntityParameter.new(2_i64)
      
      case task.actionInfo.action
      when Device::StateAction::ReadDateTime
        time = event.value
        case time
        when Time
          @database.writeTime(device.dataSource,
          parameter, nil, time)
        end              
      end
    end

    # Process data event from driver
    private def processDataEvent(device : CollectorDevice, task : CollectorDataTask, event : TaskDataResponseEvent) : Void
      # TODO: remove
      parameter = EntityParameter.new(2_i64)
      data = event.value

      case data
      when Float64
        @database.writeValue(device.dataSource,
          parameter, nil, data)
      when TimedDataValue
        value = data.value
        case value
        when Float64
          @database.writeValue(device.dataSource,
          parameter, data.dateTime, value)
        end        
      else
      end
    end

    # Process task response event from driver
    private def processTaskResponseEvent(event : DriverTaskResponseEvent, allTasks : Hash(Int32, ScriptTaskInfo)) : Void      
      # Get device
      # Send to someone to write data for parameter
      taskInfo = allTasks[event.taskId]?
      return if taskInfo.nil?

      task = taskInfo.task

      case task
      when CollectorActionTask
        processActionEvent(taskInfo.device, task, event)
      when CollectorDataTask
        case event
        when TaskDataResponseEvent
          processDataEvent(taskInfo.device, task, event)
        end        
      end
    end

    # Process driver event
    private def processDriverEvent(event : CollectorDriverEvent, allTasks : Hash(Int32, ScriptTaskInfo)) : Void
      begin
        case event
        when DriverTaskResponseEvent
          processTaskResponseEvent(event, allTasks)
        else
          raise NorthwindException.new("Unsupported driver event")
        end
      rescue e : Exception
        puts e.inspect_with_backtrace
      end
    end

    # Collect data from common drivers for it's devices
    private def collectByDriver(driver : CollectorDriver, driverDevices : Array(CollectorDevice))
      now = Time.now
      startTime = now + Time::Span.new(@deep, 0, 0)
      endTime = now
      interval = DateInterval.new(startTime, endTime)
      tasks = Array(CollectorTask).new
      allTasks = Hash(Int32, ScriptTaskInfo).new

      driver.listen do |event|
        processDriverEvent(event, allTasks)
      end

      # Append task in other fiber
      driverDevices.each do |device|
        tasks.clear

        @actions.each do |act|
          tasks << CollectorActionTask.new(act)
        end

        @parameters.each do |par|
          tasks << CollectorDataTask.new(par, interval)
        end

        tasks.each do |x|
          allTasks[x.taskId] = ScriptTaskInfo.new(
            device, x
          )
        end

        # TODO: Timeout
        # TODO: Catch driver errors
        begin
          driver.appendTask(CollectorDeviceTasks.new(device, tasks))
        rescue e : Exception
          # TODO: diagnostics
          puts e.inspect_with_backtrace
        end
      end
    end

    # Start schedule of script
    private def startSchedule : Void
      return unless @isWorking

      nextStart = @schedule.nextStart
      # TODO: notifyMessage
      puts "Name: #{@name} Next start: #{nextStart}"

      # TODO: script execution timeout
      Future.delayed(nextStart) do
        startTime = Time.monotonic
        startCollect
        executeTime = Time.monotonic - startTime
        # Wait for complete
        executeCompleter!.complete(ScriptCompleteInfo.new(
          executeTime: executeTime
        ))
      end.catch do |e|
        # TODO notify error
        # executeCompleter!.completeError(e)
        p e.inspect_with_backtrace
      end
    end

    # Start collect from all devices in scripts
    private def startCollect : Void
      puts "Start collect"
      puts "Devices: #{@devices.size}"
      puts "Parameters: #{@parameters.size}"
      puts "Actions: #{@actions.size}"
      puts "Deep: #{@deep}"

      futures = Array(Future(Void)).new

      @devices.each.group_by { |x| x.route }.each do |route, routeDevices|
        futures << Future(Void).new do
          begin
            channel = TransportChannelFactory.get(route)

            case channel
            when ClientTransportChannel
              channel.open

              routeDevices.group_by { |x| x.driver }.each do |driver, driverDevices|
                # Set channel to protocol if driver with protocol
                if protDriver = driver
                  protDriver.protocol.channel = channel
                  collectByDriver(protDriver, driverDevices)
                end
              end

              channel.close
            else
              # TODO: other types of channels
              puts "Unsupported channel type"
            end
          rescue e : Exception
            # TODO: diagnostics
            puts "startCollect"
            puts e.inspect_with_backtrace
          end
        end
      end

      Future.waitAll(futures)
    end

    def initialize(@name, @schedule, @collectorWorker, @database)
      @devices = Set(CollectorDevice).new
      @parameters = Set(MeasureParameter).new
      @actions = Set(DeviceAction).new
    end

    # Start work
    def start : Future(ScriptCompleteInfo)
      @executeCompleter = Completer(ScriptCompleteInfo).new

      @isWorking = true
      startSchedule

      return executeCompleter!.future
    end

    # Add device to script
    def addDevice(device : CollectorDevice) : Void
      @devices.add(device)
    end

    # Add parameter
    def addParameter(parameter : MeasureParameter) : Void
      @parameters.add(parameter)
    end

    # Add action
    def addAction(action : DeviceAction) : Void
      @actions.add(action)
    end
  end
end
