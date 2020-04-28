$CheckDatabases = "SHOW DATABASES;"

$CreateDBCommandSet = `
"CREATE DATABASE $DBname character set utf8 collate utf8_unicode_ci;
CREATE USER '$DBuser'@'%' IDENTIFIED BY '$DBpass';
GRANT ALL PRIVILEGES ON $DBname.* TO '$DBuser'@'%' IDENTIFIED BY '$DBpass';
FLUSH PRIVILEGES;
"
$CreateDBTablesCommandSet = `
"CREATE TABLE t_filename
(
filename_id int unsigned NOT NULL auto_increment,
filename varchar(255) NOT NULL,
Time_stamp datetime,
Unique (filename),
Index (filename),
constraint pk_t_filename primary key (filename_id)
); 

CREATE TABLE t_filetype
(
filetype_id int unsigned NOT NULL auto_increment,
filetype varchar(255) NOT NULL,
Time_stamp datetime,
Unique (filetype),
Index (filetype),
constraint pk_t_filetype primary key (filetype_id)
); 

CREATE TABLE t_path
(
path_id int unsigned NOT NULL auto_increment,
path varchar(255) NOT NULL,
etalon bool,
Time_stamp datetime,
Unique (path),
Index (etalon),
Index (path),
constraint pk_t_path primary key (path_id)
); 

CREATE TABLE t_hash
(
filename_id int unsigned NOT NULL,
filetype_id int unsigned NOT NULL,
path_id int unsigned NOT NULL,
Sha256hash char(64) NOT NULL,
filesize int unsigned,
fileTS datetime,
Time_stamp datetime,
Unique (Sha256hash),
INDEX (Sha256hash),
INDEX (fileTS),
constraint pk_t_hash primary key (filename_id,filetype_id,path_id),
FOREIGN KEY (filename_id) REFERENCES t_filename(filename_id),
FOREIGN KEY (filetype_id) REFERENCES t_filetype(filetype_id),
FOREIGN KEY (path_id) REFERENCES t_path(path_id)
); 
"
