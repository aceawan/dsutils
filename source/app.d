import std.stdio;
import std.file;
import std.conv;
import std.datetime;
import std.array;

enum UTMP_FILE = "/var/run/utmp";

void main()
{
	
	auto users = users();

	foreach(u; users){
		writef("User : %s\n", u.user);
		writef("Terminal : %s\n", u.terminal);
		writef("Host: %s\n", u.host);
		writef("Started : %s\n", u.tv_sec);
	}
}


/*
 * Everything about the connected users on the system
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

 union UnionUtmp
 {
 	ubyte[UtmpC.sizeof] byteArray;
 	UtmpC utmp;
 }

 enum{
 	RUN_LVL=1,
 	BOOT_TIME=2,
 	NEW_TIME=3,
 	OLD_TIME=4,
 	INIT_PROCESS=5,
 	LOGIN_PROCESS=6,
 	USER_PROCESS=7,
 	DEAD_PROCESS=8,
 }

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

 char[] intarrToCharr(int[] arr){
 	char[] result;

 	result.length = arr.length;

 	foreach(i, e; arr){
 		result[i] = to!char(e);
 	}

 	return result;
 }