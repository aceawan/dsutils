 module dsutils.process;

import dsutils.processes;
import std.stdio;
import std.string;
import std.conv;
import std.algorithm;

struct Process{
	private int _pid;

	public this(int pid){
		if(pid < 0 || !pidExists(pid)){
			throw new Exception("pid number not valid");
		}

		this._pid = pid;
	}

	@property
	public int pid(){
		return this._pid;
	}

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

	@property
	public string name(){
		File f = File("/proc/" ~ to!string(this._pid) ~ "/stat");

		return (f.readln().split(" ")[1])[1..$-1];
	}

	@property
	public string cmdline(){
		File f = File("/proc/" ~ to!string(this._pid) ~ "/cmdline");

		return f.readln().split(0x00)[$-2];
	}
}