package collector;

import collector.database.Database;
import collector.database.DbDevice;
import core.time.schedule.PeriodicSchedule;
import core.time.TimeSpan;
import core.io.port.Parity;

import collector.common.CollectorWorker;
import collector.common.CollectorDevice;
import collector.common.route.DirectSerialRoute;
import collector.common.parameters.DeviceAction;

import collector.appdrivers.teplokom.vkt7like.Vkt7likeDriver;

/**
 * Launches all
 */
class Collector {
	/**
	 * Entry point
	 */
	public static function main() {
		// Prepare database
		Database.instance.open();
		var devices = Database.instance.getEntities(DbDevice);
		for (dev in devices) {
			trace(dev);
		}
		// trace(device);

		// var device = Database.instance.createEntity(DbDevice);
		// device.modelType = "Vkt7";
		// device.protocolType = "ModbusRtuProtocol";
		// Database.instance.saveEntity(device);

		// device = Database.instance.createEntity(DbDevice);
		// device.modelType = "Vkt7";
		// device.protocolType = "ModbusRtuProtocol";
		// Database.instance.saveEntity(device);
		
		
		//trace(dev.protocolType);

		// var worker = new CollectorWorker();
		// worker.registerDriver(Vkt7likeDriver);

		// var schedule = new PeriodicSchedule(
		// 	new TimeSpan({seconds:10})
		// );
		// var script = worker.newScript("Collect data", schedule);
		// script.addDevice(new CollectorDevice("2313", "Vkt7", "ModbusRtuProtocol", new DirectSerialRoute("COM4", 9600, {
		// 	dataBits: 8,
		// 	parity: Parity.None,
		// 	stopBits: 1
		// })));
		// script.addAction(new DeviceAction(ActionType.ReadDateTime));
		// worker.start();
	}
}
