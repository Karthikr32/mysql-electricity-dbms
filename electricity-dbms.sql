create database sql_project;
use sql_project;

show tables;

/*
Project Task 1: Update the payment_status in the billing_info table based on the cost_usd value. Use CASE...END logic.
*/
select * from billing_info;

delimiter ==
create procedure update_payment_status() 
begin
update billing_info set payment_status = 
 case
 when cost_usd > 200 then "High"
 when cost_usd > 100 and cost_usd < 200 then  "Medium"
 else "Low"
 end;
 select * from billing_info;
end ==
delimiter ;

call update_payment_status();

drop procedure if exists update_payment_status;



/*
Project Task 2: (Using Group by) For each household, show the monthly electricity usage, rank of usage within each year, and classify usage level.
*/

select * from household_info;
select * from billing_info;

-- 1. use billing_info bcz, it has month, year total cost detials
-- 2. shows monthly usage
-- 3. Rank them usage by year
select household_id, year, month, total_kwh, rank() over(
partition by year order by total_kwh desc) as usage_rank,
case
when sum(total_kwh) > 500 then "High"
else "Low"
end as usage_lvl
from billing_info group by household_id, year, month, total_kwh;


/*
Project Task 3:
Create a monthly usage pivot table showing usage for January, February, and March.
*/

select household_id, 
 sum(case when month = 'Jan' then cost_usd else 0 end) as Jan_uasage,
sum(case when month = 'Feb' then cost_usd else 0 end) as Feb_usage,
sum(case when month = 'Mar' then cost_usd else 0 end) as Mar_usage
from billing_info group by household_id;



/*
Project Task 4: Show average monthly usage per household with city name.
*/
select bi.household_id, bi.month, hi.city, avg(total_kwh) as avg_uasge 
from billing_info bi join household_info hi on hi.household_id = bi.household_id 
group by bi.household_id, bi.month, hi.city;


/*
Project Task 5: Retrieve AC usage and outdoor temperature for households where AC usage is high.
*/

select au.household_id, au.kwh_usage_AC, ed.avg_outdoor_temp from appliance_usage au join 
environmental_data ed on au.household_id = ed.household_id where au.kwh_usage_AC > 100;


/*
Project Task 6: Create a procedure to return billing info for a given region.
*/

select * from billing_info;
show tables;
select * from household_info;

delimiter //
create procedure getby_region(in place varchar(30))
begin
 select bi.household_id, bi.month, bi.year, hi.region, bi.billing_cycle,
 bi.payment_status, bi.rate_per_kwh, bi.cost_usd, bi.total_kwh
 from billing_info bi join household_info hi
 on bi.household_id = hi.household_id
 where hi.region = place;
end //
delimiter ;

call getby_region('North');


/*
Project Task 7: Create a procedure to calculate total usage for a household and return it.
*/

delimiter ^^
create procedure get_total_usage(in id text, inout total_usage decimal(10, 2))
begin
 select round(sum(cost_usd), 2) from billing_info bi
 where bi.household_id = id
 into total_usage;
end ^^
delimiter ;

call get_total_usage('H0001', @total_usage);
select @total_usage;

select * from household_info;
select * from billing_info;

drop procedure if exists get_total_usage;


/*
Project Task 8: Automatically calculate cost_usd before inserting into billing_info.
*/

delimiter $$
create trigger cal_cost_usd before insert
on billing_info for each row
begin
if new.cost_usd is null then set 
new.cost_usd = round(new.rate_per_kwh * new.total_kwh, 2);
end if;
end $$
delimiter ;

show triggers;

insert into billing_info values
('H5001', 'Dec', 2025, '2025-01-01 to 2025-01-30', 'High', 0.18, null, 1277.6),
('H5002', 'Jan', 2025, '2025-01-01 to 2025-01-30', 'High', 0.18, null, 1874.93);

show tables;

select * from billing_info;



/*
Project Task 9 : After a new billing entry, insert calculated metrics into calculated_metrics.
•	Hint1: Use AFTER INSERT trigger and NEW keyword.
•	Hint 2:  Calculations(metrics)

House hold_id = new.house_hold_id
KWG per_occupant = total_kwh /Num_occupants
Usage category = total_kwh > 600 set “High” else “Moderate”

*/

-- Needed tables for this project
select * from calculated_metrics;
select * from billing_info;
select * from household_info;

-- Create 3 dummy variables with same DataType used in calculated_metrics:
 -- 1.) variable 1 is to Extract the data of "Num_occupants" is avail in household_info
 -- 2.) variable 2 is to store the results of calculation (total_kwh / Num_occupants) 
 -- 3.) variable 3 to assign usage_category like high or low using case-end

delimiter !!
create trigger get_updated_metrics
after insert on billing_info 
for each row
begin
  -- declare 3 variables as we planned
  declare house_num_count int;
  declare kwh_num_result decimal(10, 2);
  declare case_end_result varchar(10);
  
  -- 1. Extract num_occupants from household table
  select num_occupants from household_info 
  where household_id = new.household_id
  into house_num_count;
  
  -- 2. Make calculation to (total_kwh / Num_occupants) 
  set kwh_num_result = new.total_kwh / house_num_count;
  
  
  -- 3. Making case-end to determine whether it is high or moderate by analysing = total_kwh > 600 
  set case_end_result = case 
  when new.total_kwh > 600 then "High"
  else "Moderate"
  end;
  
 insert into calculated_metrics (household_id, kwh_per_occupant, usage_category)
 values (new.household_id, kwh_num_result, case_end_result);
end !!
delimiter ;

-- checking present/not
show triggers;

-- Testing :
 -- 3 steps:
 -- i.) insert values into household table (bcz of num_occupant)
 -- ii.) insert values into billing_info table (actual insertion)
 -- iii.) Review the calculated_metrics table

insert into household_info values
('H9000', 'South', 'Lakeland', 12345, 'Apartment', 2793, 4, 'Yes');

insert into billing_info values
('H9000', 'Dec', 2025, '2025-07-01 to 2025-07-30', 'High', 0.18, 200.00, 1100);

select * from calculated_metrics;

