create table delivery_point (
    dpid integer not null,
    address_line_1 varchar(50) not null,
    address_line_2 varchar(500) not null,
    primary key (dpid));

drop table delivery_point;

select count(*) from delivery_point;

select * from delivery_point where dpid = 90205292;
