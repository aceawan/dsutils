module dsutils.memory;

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
 * Virtual Memory related
 */

/**
 * Svmem contains informations about
 * virtual memory.
 */
alias Svmem = Tuple!(int, "total", int, "free", int, "buffer", int, "cached", int, "freeTotal", int, "inUse");

/**
 * Returns: a Svmem tuple
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
 * 		mem = a Svmem tuple
 * 		value = a value to convert
 * Returns: a percentage
 */
int memToPercent(Svmem mem, int value){
	return value*100 / mem.total;
}

/*
 * Swap
 */
alias Swap = Tuple!(long, "total", long, "used", long, "free", int, "percent", long, "sin", long, "sout");

Swap swapMemory(){
	import core.sys.linux.sys.sysinfo;

	sysinfo_ infos;

	sysinfo(&infos);

	Swap result = Swap();

	result.total = infos.totalswap * infos.mem_unit;
	result.free = infos.freeswap * infos.mem_unit;
	result.used = result.total - result.free;

	if(result.total != 0){
		result.percent = to!int((result.used / result.total) * 100);
	}

	File f = File("/proc/vmstat");

	bool in_found = false;
	bool out_found = false;

	foreach(line; f.byLine()){
		if(line.startsWith("pswpin")){
			result.sin = to!int(line.split(" ")[1]) * 4 * 1024;
			in_found = true;
		}

		if(line.startsWith("pswpout")){
			result.sin = to!int(line.split(" ")[1]) * 4 * 1024;
			out_found = true;
		}

		if(in_found && out_found){
			break;
		}
	}

	if(!in_found || !out_found){
		throw new Exception("sin and sout swap stats couldn't be found, they were set to 0");
	}

	return result;
}