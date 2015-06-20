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
		string result = readLink("/proc/" ~ to!string(this._pid) ~ "/exe");

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

	/**
	 * The parent process as a Process struct.
	 * Checks if the pid of the parent process has been reused and
	 * returns null if it is true.
	 * Returns: a Process or null
	 */
	@property
	public Process parent(){
		Process parent;

		try{
			parent = Process(this.ppid);

			if(parent.createTime < this.createTime){
				return parent;
			}
		}
		catch(Exception e){
			return parent;
		}

		return parent;
	}

	/**
	 * The current status of the process
	 * Returns: a value from PROC_STATUS
	 */
	@property
	public string status(){
		File f = File("/proc/" ~ to!string(this._pid) ~ "/status");

		foreach(line; f.byLine()){
			if(line.startsWith("State:")){
				return line.split(" ")[0].split("\t")[1].idup;
			}
		}

		throw new Exception("Couldn't found the process status");
	}

	/**
	 * absolute path of the current working directory
	 * of the process.
	 * Returns: a string containing a path
	 * Throws: a FileException if you don't have the rights
	 * on the /proc/{pid}/cwd file
	 */
	@property
	public string cwd(){
		string result = readLink("/proc/" ~ to!string(this._pid) ~ "/cwd");

		return result;
	}
}

enum PROC_STATUS{
	RUN = "R",
	SLEEP = "S",
	DISK_SLEEP = "D",
	STOP = "T",
	TRACING_STOP = "t",
	ZOMBIE = "Z",
	DEAD = "X",
	WAKE_KILL = "K",
	WAKING = "W"
}