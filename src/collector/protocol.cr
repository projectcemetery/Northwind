module Collector
  # Data for sending to protocol
  abstract class ProtocolRequest
  end

  # Data from protocol
  abstract class ProtocolResponse
  end

  # Abstract protocol
  abstract class Protocol
    # All known protocols
    class_property knownProtocols = Hash(String, Protocol.class).new

    # Get protocol by name
    def self.get(name : String) : Protocol
      protCls = Protocol.knownProtocols[name]?
      return protCls.new if !protCls.nil?
      raise NorthwindException.new("Unknown protocol")
    end

    macro register()
      #Protocol.knownProtocols["{{ @type.id }}"] = {{ @type }}
    end

    # Channel to send data
    @channel : TransportChannel?

    def channel=(chan : TransportChannel)
      @channel = chan
      # channel!.onChannelData do |data, count|
      #     onChannelData(data, count)
      # end
    end

    def channel!
      @channel.not_nil!
    end

    def initialize
    end

    # Send applied request
    # And yields response
    abstract def sendRequestWithResponse(request : ProtocolRequest) : ProtocolResponse
  end

  # Factory that creates protocols
  class ProtocolFactory
    # Get protocol by protocol type and route
    def self.get(protocolType : String, route : DeviceRoute) : Protocol
      protCls = Protocol.knownProtocols[name]?
      return protCls.new if !protCls.nil?
      raise NorthwindException.new("Unknown protocol")
    end
  end
end
