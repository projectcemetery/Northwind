package collector.common;

import haxe.MainLoop;
using core.utils.StringHelper;

/**
 * Information about device for internal use in collector
 */
class CollectorDevice {
	/**
	 * Serial number of device
	 */
	public final serial:String;

	/**
	 * Type of device(meter type)
	 */
	public final deviceType:String;

	/**
	 * Type of transport protocol
	 */
	public final protocolType:String;

	/**
	 * Constructor
	 */
	public function new(serial:String, deviceType:String, protocolType:String) {
		this.serial = serial;
		this.deviceType = deviceType;
		this.protocolType = protocolType;		
	}

	/**
	 * Calc hash
	 * @return Int
	 */
	public function hashCode():Int {
		return deviceType.hashCode() ^ protocolType.hashCode();
	}

	/**
	 * Compare objects
	 * @param other
	 * @return Bool
	 */
	public function equals(other:Dynamic):Bool {
		if (Std.is(other, CollectorScript)) {
			return hashCode() == cast(other, CollectorScript).hashCode();
		}

		return false;
	}
}