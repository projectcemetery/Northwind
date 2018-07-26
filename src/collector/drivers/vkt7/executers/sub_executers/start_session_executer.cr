module Vkt7Driver
  # Start session and return version of device
  class StartSessionExecuter < BaseExecuter(UInt8)
    # Execute and iterate values in block
    def execute(&block : UInt8 -> _)
      network = @deviceInfo.networkNumber.to_u8
      data = Bytes[0xCC, 0x80, 0x00, 0x00, 0x00]
      # Start session
      @protocol.sendRequestWithResponse(
        PresetMultipleRegistersRequest.new(network, Vkt7StartAddress::StartSessionAddress, 0_u16, data))

      response = @protocol.sendRequestWithResponse(ReadHoldingRegistersRequest.new(network, Vkt7StartAddress::ReadDataAddress, 0_u16))
      yield response.data[64]
    end
  end
end