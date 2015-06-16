module dsutils.process;

import dsutils.processes;
import std.stdio;
import std.string;
import std.conv;
import std.algorithm;

struct Process{
	private int pid;

	public this(int pid){
		if(pid < 0 || !pidExists(pid)){
			throw new Exception("wrong pid number");
		}

		this.pid = pid;
	}

	public int getPid(){
		return this.pid;
	}

	public int ppid(){
		File f = File("/proc/" ~ to!string(this.pid) ~ "/status");

		foreach(line; f.byLine()){
			if(line.startsWith("PPid")){
				return to!int(line.split(":")[1].strip);
			}
		}

		throw new Exception("didn't found ppid");
	}
}