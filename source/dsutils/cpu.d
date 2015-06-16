module dsutils.cpu;

import std.stdio;
import std.math;
import std.range;
import std.file;
import std.conv;
import std.typecons;
import std.datetime;
import std.array;
import std.traits;
import std.string;
import std.algorithm;
import std.uni;
import core.thread;

/*
 * CPU Related
 */

CPUTimes _cpu_times;
CPUTimes[] _cpu_times_per_cpu;

/**
 * A struct that contains all the times you can find in a line
 * of /proc/stat.
 */
struct CPUTimes{

	float user; //Normal processes executing in user mode
	float nice; //Niced processes executing in user mode
	float system; //Processes executing in kernel mode
	float idle; // Twiddling thumbs
	float iowait; // waiting for I/O to complete
	float irq; // Servicing interrupts
	float softirq; // Servicing softirqs

	float sum(){
		return user+nice+system+idle+iowait+irq+softirq;
	}

	@property
		bool empty(){
			return (isNaN(user) && isNaN(nice) && isNaN(system) && isNaN(idle) && isNaN(iowait) && isNaN(irq) && isNaN(softirq));
		}
}

/**
 * Returns: the system-wide cpu times.
 */
CPUTimes cpuTimes(){
	import core.sys.posix.unistd;

	File f = File("/proc/stat", "r");

	string line = f.readln();

	if(!startsWith(line, "cpu")){
		throw new Error("Couldn't read cpu times");
	}

	auto float_times = map!(a => to!float(a) / (sysconf(_SC_CLK_TCK) ))(split(line, " ")[2..9]);

	return CPUTimes(float_times[0], float_times[1], float_times[2], float_times[3], float_times[4], float_times[5], float_times[6]);
}

/**
 * The first cpuTime is for cpu0, the second for cpu1 etc ...
 * Returns: a list of cpu_times
 */
CPUTimes[] cpuTimesPerCpu(){
	import core.sys.posix.unistd;

	File f = File("/proc/stat", "r");

	string line = f.readln();

	line = f.readln();
	auto app = appender!(CPUTimes[])();

	while(line !is null && startsWith(line, "cpu")){
		auto float_times = map!(a => to!float(a) / (sysconf(_SC_CLK_TCK)) )(split(line, " ")[1..8]);
		auto cpu_times = CPUTimes(float_times[0], float_times[1], float_times[2], float_times[3], float_times[4], float_times[5], float_times[6]);

		app.put(cpu_times);
		line = f.readln();
	}

	return app.data;
}

/**
 * Returns: number of cpus
 * Params:
 * 		logical = boolean to tell the function if you
 * 		want to count the physicial or logicals cpus.
 */
int nbCpu(bool logical=true){
	if(logical){
		import core.sys.posix.unistd;

		int nbCpu = to!int(sysconf(_SC_NPROCESSORS_ONLN));

		if(nbCpu > 0){
			return nbCpu;
		}

		else{
			File f = File("/proc/cpuinfo", "r");
			nbCpu = 0;

			foreach(line; f.byLine()){
				if(startsWith(line, "processor")){
					nbCpu++;
				}
			}

			return nbCpu;
		}
	}

	else{
		File f = File("/proc/cpuinfo", "r");
		char[] cpus;

		foreach(line; f.byLine()){
			if(startsWith(line, "physical id")){
				if(!canFind(cpus, strip(split(line, ":")[1]))){
					cpus ~= strip(split(line, ":")[1]);
				}
			}
		}

		return to!int(cpus.length);
	}
}

float cpuPercent(int interval = 0){
	CPUTimes before;

	if(interval > 0){
		before = cpuTimes();
		Thread.sleep(dur!("seconds")(interval));
	}
	else{
		if(_cpu_times.empty){
			_cpu_times = cpuTimes();
			Thread.sleep(dur!("seconds")(1));
			before = _cpu_times;
		}
		else{
			before = _cpu_times;
			_cpu_times = cpuTimes();
		}
	}

	auto after = cpuTimes();

	return calculate(before, after);
}

float[] cpuPercentPerCpu(int interval = 0){
	CPUTimes[] before;

	if(interval > 0){
		before = cpuTimesPerCpu();
		Thread.sleep(dur!("seconds")(interval));
	}

	else{
		if(_cpu_times_per_cpu.length == 0){
			_cpu_times_per_cpu = cpuTimesPerCpu();
			Thread.sleep(dur!("seconds")(2));
			before = _cpu_times_per_cpu;
		}
		else{
			before = _cpu_times_per_cpu;
			_cpu_times_per_cpu = cpuTimesPerCpu();
		}
	}

	auto after = cpuTimesPerCpu();
	auto app = appender!(float[])();

	foreach(cpu; zip(before, after)){
		app.put(calculate(cpu[0], cpu[1]));
	}

	return app.data;
}

float calculate(CPUTimes t1, CPUTimes t2){
	auto t1_all = t1.sum();
	auto t1_busy = t1_all - t1.idle;

	auto t2_all = t2.sum();
	auto t2_busy = t2_all - t2.idle;

	return ((t2_busy - t1_busy)/(t2_all - t1_all)) * 100;
}