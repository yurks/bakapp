# Backup tools

Host, database backup tools.

## Installation

Use bash command to download and unpack archive: 

```bash
$ curl -L https://github.com/yurks/bakapp/archive/master.tar.gz | tar -xvzf -; mv bakapp-master bakapp
```

or [take it manually](https://github.com/yurks/bakapp/archive/master.tar.gz).
Then go to extracted `bakapp` dir and use `make` command for prepare all stuff to run properly:

```bash
$ make
```


## $ ./bakapp

Create backup with files or database, diff files with last backup, restore backups.

```
Usage:
    ./bakapp.sh <mode> <path> [options...]

Mode:
    create           create backup
    test             test contents of last created backup
    list             list files to backup
    diff             show differences between last created backup and files actually present in filesystem
    diff-create      create backup ONLY if any diff detected
    restore          restore backup

Path:
    directory for backup or
    database connection string in format db://user:password@host[:port]/database or
    path to backup file for restore mode

Options:
    -e               exclude dir (relative to <path>, multiple options allowed).
    -i               include only specified dir (relative to <path>, multiple options allowed).
    -o               out path for backups (default: current dir)
    -b               base path for <path> (default: current dir)
    -n               backup name (default: generated from <path>)
    -c               compression for backup file acceptable by tar (default: uncompressed)
    -d               compare files by content (diff* modes)
    -x               no colors in output
    -h               unbelievable
```


## $ ./bakme

Packet backup for web application.
Define several backup points for `backapp` tool for run all of them at once.

```
Usage:
    ./bakme.sh <prjpath> <app|content|db> restore <backupfile> [outpath]
    ./bakme.sh <prjpath> [all]|<app|content|db> [diff-create]|<create|diff|test|list>
```

Place file `.bakme` in project root with config like:

```bash
# web application name, optional.
name=app_name
# backup path (absolute or relative to project folder)
out=../bak
# entry point for backup all files in ./ path relative to project dir,
# excluding ./files ./error_log (-e),
# with lzma compression (-c lzma) 
# and check files difference by content with last created backup before creating (-d)
app=./ -e files -e error_log -e cgi-bin -c lzma -d
# entry point for backup all files in ./files path relative to project dir,
# excluding ./files/css and ./files/js (-e)
content=./files -e css -e js
# entry point for backup database files in ./files path relative to project dir, excluding ./files/css and ./files/js
# with lzma compression (-c lzma)
# excluding cache, sessions and history tables content in db (-e),
db=./db_user:db_password@db_host/db_name -c lzma -e cache -e sessions -e history
```

Options from `backapp` tool available here.


## $ ./mailsend

Sending mail using `php` for mail generating and and `sendmail` for sending.

```
Usage:
    echo "Mail body" | ./mailsend.sh -r recipient [options...]

Options:
    -r recipient     mail recipient
    -s subject       mail subject
    -f from_address  mail from address

Mail body:
    Multi-line mail body. Could contain lines starting with "@@MAILGEN:<key>@@"

    @@MAILGEN:attachment@@filename.ext
    @@MAILGEN:attachment@@/optional/path_to/project/filename.ext
        attach content as file with "filename.ext"
        and set message subject to "project/filename.ext" if path specified

    @@MAILGEN:subject@@Mail subject
        generate mail with "Mail subject" if no cli option provided

    @@MAILGEN:recipient@@Mail recipient
        add "Mail recipient" in addition to cli option provided

```


## $ ./bakmejob

Just running `bakme` for `prjpath` and send execution log to `recipient` with `mailsend`.
Options from `mailsend` tool available here.

```
Usage:
    ./bakmejob.sh <prjpath> <-r recipient...>
```


## License

[MIT license](LICENSE)
