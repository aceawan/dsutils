 module dsutils.process;

import std.stdio;
import std.file;
import std.string;
import std.conv;
import std.algorithm;

struct Process{
	private int _pid;
	private float _createTime;

	public this(int pid){
		import dsutils.processes;

		if(pid < 0 || !pidExists(pid)){
			throw new Exception("pid number not valid");
		}

		this._pid = pid;
		this._createTime = -1;
	}

	/**
	 * pd of the process
	 */
	@property
	public int pid(){
		return this._pid;
	}

	/**
	 * pid of the parent process
	 */
	@property
	public int ppid(){
		File f = File("/proc/" ~ to!string(this._pid) ~ "/status");

		foreach(line; f.byLine()){
			if(line.startsWith("PPid")){
				return to!int(line.split(":")[1].strip);
			}
		}

		throw new Exception("didn't found ppid");
	}

	/**
	 * Name of the process
	 */
	@property
	public string name(){
		File f = File("/proc/" ~ to!string(this._pid) ~ "/stat");

		return (f.readln().split(" ")[1])[1..$-1];
	}

	/**
	 * cmdline entered to launch the process
	 */
	@property
	public string cmdline(){
		File f = File("/proc/" ~ to!string(this._pid) ~ "/cmdline");

		return f.readln().split(0x00)[$-2];
	}

	/**
	 * absolute path to the executable of the process
	 * Throws: FileException if you do not have permission
	 * to read the executable
	 */
	@property
	public string exe(){
		string result;

		result = readLink("/proc/" ~ to!string(this._pid) ~ "/exe");

		return result;
	}

	/**
	 * The process creation time in seconds since epoch, in UTC
	 * The return value is cached
	 * Returns: a float
	 */
	@property
	public double createTime(){
		import core.sys.posix.unistd;
		import dsutils.misc;

		if(_createTime != -1)
			return _createTime;
		

		File f = File("/proc/" ~ to!string(this._pid) ~ "/stat");

		double uptime = to!double(f.readln().split(" ")[21]);

		return (uptime / sysconf(_SC_CLK_TCK)) + bootTime();
	}
}