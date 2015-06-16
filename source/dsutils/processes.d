module dsutils.processes;

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

/**
 * pids
 */

/**
 *Get all the pid currently active on the system
 * Return a list of the pids
 */
int[] pids(){
	int[] pidArray;
	foreach(dir; dirEntries("/proc/", "[123456789]*", SpanMode.shallow)){
		auto pid = dir.name.split("/");
		pidArray ~= to!int(pid[2]);
	}
	return pidArray;
}

/**
  * Check if a pid exists
  * Params:
  * 	pid = pid of the process
  */
bool pidExists(int pid){
	return exists("/proc/" ~ to!string(pid));
}