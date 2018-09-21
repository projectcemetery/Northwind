package collector.common;

import core.time.schedule.ISchedule;
import core.async.Future;
import core.collections.HashSet;
import collector.common.appdriver.CollectorDriver;
import collector.common.CollectorScript;

/**
 * Main working class of Collector that launches collector scripts
 */
class CollectorWorker {
	/**
	 * Is collector working
	 */
	private var isWorking:Bool;

	/**
	 * Scripts that collects data
	 */
	private final scripts:HashSet<CollectorScript>;

	/**
	 * Known drivers that can collect data
	 */
	private final drivers:HashSet<CollectorDriver>;

	/**
	 * Constructor
	 */
	public function new() {
		scripts = new HashSet<CollectorScript>();
		drivers = new HashSet<CollectorDriver>();
		isWorking = false;
	}

	/**
	 * Create new script for collecting data, and puts in to scripts hash set
	 * @return CollectorScript
	 */
	public function newScript(name:String, schedule:ISchedule):CollectorScript {
		var script = new CollectorScript(name, schedule);
		scripts.add(script);
		return script;
	}

	/**
	 * Start collector
	 */
	public function start() {
		isWorking = true;
		while (isWorking) {
			for (script in scripts) {
				script.start();
			}
		}
	}
}
