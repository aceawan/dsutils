module dsutils.disks;

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
 * Disk
 */

/**
 * Represent a partition mounted on the system
 */
alias Partition = Tuple!(string, "device", string, "mountPoint", string, "fstype", string, "opts");

/**
 * Get all the partition mounted on the system
 * Params:
 * 		all = if false, returns only physicals devices
 * 		if true, returns all the devices
 * Returns: a list of partition
 */
Partition[] diskPartitions(bool all = false){
	File f = File("/proc/filesystems");
	auto dev_fs = appender!(string[])();

	foreach(line; f.byLine()){
		if(!startsWith(line, "nodev")){
			dev_fs.put(line.strip.idup);
		}
	}

	f = File("/etc/mtab");

	auto parts = appender!(Partition[])();

	foreach(line; f.byLine()){
		auto splitted_line = line.split(" ");

		if(!all){
			if(dev_fs.data.canFind(splitted_line[2])){
				Partition p = Partition();
				p.device = splitted_line[0].idup;
				p.mountPoint = splitted_line[1].idup;
				p.fstype = splitted_line[2].idup;
				p.opts = splitted_line[3].idup;
				parts.put(p);
			}
		}
		else{
			Partition p = Partition();
			p.device = splitted_line[0].idup;
			p.mountPoint = splitted_line[1].idup;
			p.fstype = splitted_line[2].idup;
			p.opts = splitted_line[3].idup;
			parts.put(p);
		}
	}

	return parts.data;
}


/**
 * Informations about the disk usage
 */
alias DiskUsage = Tuple!(ulong, "total", ulong, "used", ulong, "free", float, "percent");

DiskUsage diskUsage(string path){
	import core.sys.posix.sys.statvfs;

	auto buf = statvfs_t();

	if(statvfs(path.ptr, &buf)){
		throw new Error("Couldn't call statvfs");
	}

	auto res = DiskUsage();

	res.total = (buf.f_blocks * buf.f_frsize);
	res.used = (buf.f_blocks - buf.f_bfree) * buf.f_frsize;
	res.free = (buf.f_bavail * buf.f_frsize);
	res.percent = (to!float(res.used) / to!float(res.total)) * 100.0;

	return res;
}

/**
  * Io stats about the disk
  */
alias DiskStats = Tuple!(int, "read_count", int, "write_count", int, "read_bytes", int, "write_bytes", int, "read_time", int, "write_time");

enum SECTORSIZE = 512;

DiskStats diskIoCounters(){
	auto parts = appender!(string[])();
	File f = File("/proc/partitions");

	foreach(line; f.byLine()){
		line = line.squeeze(" ");
		if(line != "" && !startsWith(line, "major") && isNumber(line[$-1]))
			parts.put(line.split(" ")[$-1].idup);
	}

	auto result = DiskStats();

	f = File("/proc/diskstats");

	foreach(line; f.byLine()){
		auto s_line = line.squeeze(" ").split(" ")[1..$-1];

		writeln(s_line);
		if(parts.data.canFind(s_line[2].idup)){
			if(line.length > 7){
				result.read_count += to!int(s_line[3]);
				result.write_count += to!int(s_line[7]);
				result.read_bytes += to!int(s_line[5]) * SECTORSIZE;
				result.write_bytes += to!int(s_line[9]) * SECTORSIZE;
				result.read_time += to!int(s_line[6]);
				result.write_time += to!int(s_line[10]);
			}
			else{
				result.read_count += to!int(s_line[3]);
				result.write_count += to!int(s_line[5]);
				result.read_bytes += to!int(s_line[4]) * SECTORSIZE;
				result.write_bytes += to!int(s_line[6]) * SECTORSIZE;
			}
		}
	}

	return result;
}