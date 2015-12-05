module dsutils.network;

import std.typecons;
import std.algorithm;
import std.range;
import std.file;
import std.format;
import std.conv;
import std.socket;
import std.string;
import std.stdio;
import std.process;
import std.system;
import std.array;

import dsutils.processes;

alias NetIoStats = Tuple!(int, "bytes_sent", int, "bytes_recvd", int, "packets_sent", int, "packets_recvd", int, "errin", int, "errout", int, "dropin", int, "dropout");

NetIoStats netIoCounters(){
	auto lines = readText("/proc/net/dev");
	auto result = NetIoStats();

	foreach(line; lines.splitLines()[2..$]){
		auto values = line.squeeze(" ").split(":")[1].split();

		result.bytes_recvd += values[0].to!int;
		result.packets_recvd += values[1].to!int;
		result.errin += values[2].to!int;
		result.dropin += values[3].to!int;
		result.bytes_sent += values[8].to!int;
		result.packets_sent += values[9].to!int;
		result.errout += values[10].to!int;
		result.dropout += values[11].to!int;
	}

	return result;
}

NetIoStats[string] netIoCountersPerNic(){
	auto lines = readText("/proc/net/dev");
	NetIoStats[string] result;

	foreach(line; lines.splitLines()[2..$]){
		auto tmp_tuple = NetIoStats();

		auto values = line.squeeze(" ").split(":")[1].split();

		tmp_tuple.bytes_recvd += values[0].to!int;
		tmp_tuple.packets_recvd += values[1].to!int;
		tmp_tuple.errin += values[2].to!int;
		tmp_tuple.dropin += values[3].to!int;
		tmp_tuple.bytes_sent += values[8].to!int;
		tmp_tuple.packets_sent += values[9].to!int;
		tmp_tuple.errout += values[10].to!int;
		tmp_tuple.dropout += values[11].to!int;

		result[line.split(":")[0].strip] = tmp_tuple;
	}

	return result;
}

alias ConnType = Tuple!(string, AddressFamily, SocketType);

public class Connections{
	ConnType[][string] tmap;

	this(){
		auto tcp4 = tuple("tcp", AddressFamily.INET, SocketType.STREAM);
		auto tcp6 = tuple("tcp6", AddressFamily.INET6, SocketType.STREAM);
		auto udp4 = tuple("udp", AddressFamily.INET, SocketType.DGRAM);
		auto udp6 = tuple("udp6", AddressFamily.INET6, SocketType.DGRAM);
		auto unix = tuple("unix", AddressFamily.UNIX, SocketType.STREAM);

		this.tmap = [
			"all": [tcp4, tcp6, udp4, udp6, unix],
			"tcp": [tcp4, tcp6],
			"tcp4": [tcp4],
			"tcp6": [tcp6],
			"udp": [udp4, udp6],
			"udp4": [udp4],
			"udp6": [udp6],
			"unix": [unix],
			"inet": [udp4, tcp4, udp6, tcp6],
			"inet4": [udp4, tcp4],
			"inet6": [udp6, tcp6]
		];
	}

	int[][string] getProcInodes(int pid){
		int[][string] inodes;
		try{
			foreach(string fd; dirEntries("/proc/" ~ pid.to!string ~ "/fd", SpanMode.depth)){
				string inode;
				try{
					inode = readLink(fd.to!string);
				}
				catch(FileException fe){}

				if(inode.startsWith("socket:[")){
					inode = inode[8..$-1];
					inodes[inode] ~= fd.split("/")[$-1].to!int;
				}
			}
		}
		catch(FileException fe){
		}

		return inodes;
	}

	int[][string] getAllInodes(){
		int[][string] inodes;

		foreach(int pid; pids()){
			if(thisProcessID != pid){
				int[][string] procInodes = getProcInodes(pid);

				foreach(k, v; procInodes){
					auto p = (k in inodes);

					if(p !is null){
						inodes[k] ~= uniq(inodes[k] ~ procInodes[k]).array;
					}
					else{
						inodes[k] = procInodes[k];
					}
				}

			}
		}

		return inodes;
	}

	auto decodeAddress(string address, AddressFamily family){
		string[] splittedAddr = split(address, ":");

		writeln(splittedAddr);

		auto rawPort = splittedAddr[1];

		int strPort = parse!int(rawPort, 16);

		string rawAddr;

		int[] addr_int;

		if(family == AddressFamily.INET){
			if(endian == Endian.littleEndian){
				rawAddr = splittedAddr[0].retro.text;
			}
			else{
				rawAddr = splittedAddr[0];
			}

			addr_int = rawAddr.chunks(2).map!(v => to!int(v.save().to!string, 16)).array;
		}

		return addr_int.map!(i => i.to!string).array.join(".") ~ ":" ~ strPort.to!string;
	}
}

enum CONN_STATUS {
	CONN_NONE,
	CONN_ESTABLISHED,
	CONN_SYN_SENT,
	CONN_SYN_RECV
}
