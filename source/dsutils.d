/**
 * Authors: Quentin Ladeveze, ladeveze.quentin@openmailbox.org
 */
module dsutils;

import std.stdio;
import std.math;
import std.range;
import std.file;
import std.conv;
import std.datetime;
import std.array;
import std.traits;
import std.string;
import std.algorithm;

import core.thread;

CPUTimes _cpu_times;
CPUTimes[] _cpu_times_per_cpu;

/*
 * Everything about the connected users on the system
 */
enum UTMP_FILE = "/var/run/utmp";

/**
 * A more human structure for Utmp
 * A utmp struct is an entry in UTMP_FILE
 * and represent a connection from an user.
 */
struct Utmp
{
    short type;
    int pid;
    string terminal;
    string id;
    string user;
    string host;
    short termination;
    short exit;
    int session;
    SysTime tv_sec;
    int tv_usec;
    char[4] addr;
    char[20] unused;
}

/**
 * Copy of the C structure you can found in utmp.h
 * Used to retrieve the structures in /var/run/utmp
 */
struct UtmpC
{
    short ut_type;
    int ut_pid;
    char[32] ut_line;
    char[4] ut_id;
    char[32] ut_user;
    char[256] ut_host;
    short e_termination;
    short e_exit;
    int ut_session;
    int tv_sec;
    int tv_usec;
    int[4] ut_addr_v6;
    char[20] __glibc_reserved;
}

/**
 * This is for transform the raw data in /var/run/utmp
 * into a UtmpC struct.
 */
union UnionUtmp
{
    ubyte[UtmpC.sizeof] byteArray;
    UtmpC utmp;
}

enum{
    INIT_PROCESS=5, // Process spawned by the init process
    LOGIN_PROCESS=6, // Session leader of a logged user
    USER_PROCESS=7, // Normal process
    DEAD_PROCESS=8, // Terminated process
}

/*
 * List all the users connected to the system.
 * Returns: A list of Utmp structs.
 */
Utmp[] users(){
    auto buffer = cast(ubyte[]) read(UTMP_FILE);

    short i = 0;
    Utmp[] users;

    auto app = appender!(Utmp[])();

    while(i+UtmpC.sizeof < buffer.length){
		ubyte[UtmpC.sizeof] one_buf = buffer[i..i+UtmpC.sizeof];
		auto u = UnionUtmp(one_buf);

		if(u.utmp.ut_type == USER_PROCESS){

			Utmp user = Utmp();

			user.type = u.utmp.ut_type;
			user.pid = u.utmp.ut_pid;
			user.terminal = to!string(u.utmp.ut_line);
			user.id = to!string(u.utmp.ut_id);
			user.user = to!string(u.utmp.ut_user);
			user.host = to!string(u.utmp.ut_host);
			user.termination = u.utmp.e_termination;
			user.exit = u.utmp.e_exit;
			user.session = u.utmp.ut_session;

			user.tv_sec = SysTime(unixTimeToStdTime(u.utmp.tv_sec));

			user.tv_usec = u.utmp.tv_usec;
			user.addr = intarrToCharr(u.utmp.ut_addr_v6);
			user.unused = u.utmp.__glibc_reserved;

			app.put(user);

		}

		i += UtmpC.sizeof;

    }

    return app.data;
}

/**
 * Convert a int array to a char array
 * Params:
 * 		arr = an array of int
 * Returns : an array of char
 */
char[] intarrToCharr(int[] arr){
    char[] result;

    result.length = arr.length;

    foreach(i, e; arr){
		result[i] = to!char(e);
    }

    return result;
}

/*
 * Uptime
 */

/**
 * Return the last boot's time.
 * Returns: a Systime.
 */
SysTime bootTime(){
	File f = File("/proc/stat", "r");

	string line;
	int result = -1;

	while((line = f.readln()) !is null){
		if(startsWith(line, "btime")){
			result = to!int(chomp(split(line, " ")[1]));
		}
	}

	if(result > 0){
		return SysTime(unixTimeToStdTime(result));
	}
	else{
		throw new Error("Couldn't read boot time");
	}
}

/*
 * Disk space related
 */



/*
 * CPU Related
 */

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

/**
 * Virtual Memory related
 * should work now
 */

/**
 * Svmem contains informations about
 * virtual memory.
 */
struct Svmem{
	int total;
	int free;
	int buffer;
	int cached;
	int freeTotal;
	int inUse;
}

/**
 * Returns: a Sysmem structure
 */
Svmem mem(){
	File f = File("/proc/meminfo", "r");
	string line = f.readln();
	Svmem memory;
	int i;

	for(i=0; i<5; i++){
		if(i == 0){ //MemTotal
			memory.total = memTreat(line);
		}
		if(i == 1){ // MemFree
			memory.free = memTreat(line);
		}
		if(i == 3){ //Buffer					
			memory.buffer = memTreat(line);
		}
		if(i == 4){ //Cached
			memory.cached = memTreat(line);
		}
		line = f.readln();
	}

	memory.freeTotal = memory.free + memory.buffer + memory.cached;
	memory.inUse = memory.total - memory.freeTotal;	

	return memory;	
}

/**
 * Parse a line from /proc/meminfo
 * Params: 
 * 		line = a line of /proc/meminfo
 * Returns: the value in this line
 */
int memTreat(string line){
	auto infoTmp = split(line, ":");
	auto infoQuantity = split(infoTmp[1]);
	auto result = infoQuantity[0];
	return to!int(result);
}

/**
 * Convert a value from /proc/meminfo in mega-bytes
 * Params: a value ton convert
 * Returns: the converted value
 */
int toMB(int value){
	return value/1024;
}

/**
 * Convert a value from /proc/meminfo in a percentage
 * of the total memory
 * Params:
 * 		mem = a Svmem structure
 * 		value = a value to convert
 * Returns: a percentage
 */
int toPercent(Svmem mem, int value){
	return value*100 / mem.total;		
}

/**
 * Disk 
 */

/**
 * Represent a partition mounted on the system
 */
struct Partition{
	string device; // path of the device
	string mountPoint; // mountpoint of the partition
	string fstype; // File system type
	string opts; // Options of mounting
}

/**
 * Get all the partition mounted on the system
 * Params:
 * 		all = if false, returns only physicals devices
 * 		if true, returns all the devices
 * Returns: a list of partition
 */
Partition[] diskPartions(bool all = false){
	File f = File("/proc/filesystems");
	auto dev_fs = appender!(string[])();

	foreach(line; f.byLine()){
		if(!startsWith(line, "nodev")){
			dev_fs.put(line.strip);
		}
	}

	f = File("/etc/mtab");

	auto parts = appender!(Partition[])();

	foreach(line; f.byLine()){
		auto splitted_line = line.split(" ");

		if(!all){
			if(dev_fs.canFind(splitted_line[2])){
				Partition p = Partition();
				p.device = splitted_line[0];
				p.mountPoint = splitted_line[1];
				p.fstype = splitted_line[2];
				p.opts = splitted_line[3];
				parts.put(p);
			}
		}
		else{
				Partition p = Partition();
				p.device = splitted_line[0];
				p.mountPoint = splitted_line[1];
				p.fstype = splitted_line[2];
				p.opts = splitted_line[3];
				parts.put(p);		
		}
	}

	return parts;
}