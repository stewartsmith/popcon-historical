CREATE TABLE `popcon` (
       id bigint auto_increment,
       distro varchar(100),
       popcon_date date,
       submissions bigint,
       PRIMARY KEY (id),
       UNIQUE (distro, popcon_date)
);

CREATE TABLE `popcon_release` (
       popcon_id bigint,
       popcon_release varchar(100),
       nr bigint,
       PRIMARY KEY (popcon_id, popcon_release),
       FOREIGN KEY (popcon_id) REFERENCES popcon(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE `popcon_arch` (
       popcon_id bigint,
       arch varchar(255),
       nr bigint,
       PRIMARY KEY (popcon_id, arch),
       FOREIGN KEY (popcon_id) REFERENCES popcon(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE `package` (
       id bigint auto_increment PRIMARY KEY,
       package varbinary(1000),
       UNIQUE INDEX (package(500))
) ROW_FORMAT=COMPRESSED;

CREATE TABLE `popcon_package` (
       popcon_id bigint,
       package_id bigint,
       inst_nr bigint, -- Total of below four
       vote_nr bigint, -- first nr in all_popcon results
       old_nr bigint, -- 2nd nr
       recent_nr bigint, -- 3rd nr
       no_files_nr bigint,
       PRIMARY KEY (popcon_id, package_id),
       INDEX (package_id),
       FOREIGN KEY (popcon_id) REFERENCES popcon(id) ON DELETE CASCADE ON UPDATE CASCADE,
       FOREIGN KEY (package_id) REFERENCES package(id) ON DELETE CASCADE ON UPDATE CASCADE
);
