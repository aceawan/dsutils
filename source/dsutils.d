module dsutils;

import std.stdio;
import std.math;
import std.file;
import std.conv;
import std.datetime;
import std.array;
import std.traits;
import std.string;
import std.algorithm;

import core.thread;

CPUTimes _cpu_times;

/*
 * Everything about the connected users on the system
 */
enum UTMP_FILE = "/var/run/utmp";

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

union UnionUtmp
{
    ubyte[UtmpC.sizeof] byteArray;
    UtmpC utmp;
}

enum{
    RUN_LVL=1,
    BOOT_TIME=2,
    NEW_TIME=3,
    OLD_TIME=4,
    INIT_PROCESS=5,
    LOGIN_PROCESS=6,
    USER_PROCESS=7,
    DEAD_PROCESS=8,
}

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
* CPU Related
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

CPUTimes[] cpuTimesPerCpu(){
	import core.sys.posix.unistd;

	File f = File("/proc/stat", "r");

	string line = f.readln();

	line = f.readln();
	auto app = appender!(CPUTimes[])();

	while(line !is null && startsWith(line, "cpu")){
		auto float_times = map!(a => to!float(a) / sysconf(_SC_CLK_TCK))(split(line, " ")[2..9]);
		auto cpu_times = CPUTimes(float_times[0], float_times[1], float_times[2], float_times[3], float_times[4], float_times[5], float_times[6]);

		app.put(cpu_times);
		line = f.readln();
	}

	return app.data;
}

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
			writeln("coinkou");
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

float calculate(CPUTimes t1, CPUTimes t2){
	auto t1_all = t1.sum();
	auto t1_busy = t1_all - t1.idle;

	auto t2_all = t2.sum();
	auto t2_busy = t2_all - t2.idle;

	return ((t2_busy - t1_busy)/(t2_all - t1_all)) * 100;
}