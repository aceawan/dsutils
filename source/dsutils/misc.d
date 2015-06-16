module dsutils.misc;

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
 * Everything about the connected users on the system
 */
enum UTMP_FILE = "/var/run/utmp";

/**
 * A more human structure for Utmp
 * A utmp struct is an entry in UTMP_FILE
 * and represent a connection from an user.
 */
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

/**
 * Copy of the C structure you can found in utmp.h
 * Used to retrieve the structures in /var/run/utmp
 */
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

/**
 * This is for transform the raw data in /var/run/utmp
 * into a UtmpC struct.
 */
union UnionUtmp
{
	ubyte[UtmpC.sizeof] byteArray;
	UtmpC utmp;
}

enum{
	INIT_PROCESS=5, // Process spawned by the init process
	LOGIN_PROCESS=6, // Session leader of a logged user
	USER_PROCESS=7, // Normal process
	DEAD_PROCESS=8, // Terminated process
}

/*
 * List all the users connected to the system.
 * Returns: A list of Utmp structs.
 */
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

/**
 * Convert a int array to a char array
 * Params:
 * 		arr = an array of int
 * Returns : an array of char
 */
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

/**
 * Return the last boot's time.
 * Returns: a Systime.
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