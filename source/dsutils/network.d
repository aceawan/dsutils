module dsutils.network;

import std.typecons;
import std.file;
import std.conv;
import std.string;
import std.stdio;

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