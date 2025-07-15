-- Create project database
create database nashville_project;

/* 
Data table imported from MS-Excel via python
*/

-- Check the imported data table 
SELECT * FROM nashville;

-- Clone Data table for cleaning
drop table if exists nashvilleclone;
create table nashvilleclone as (
select * from nashville);
select * from nashvilleclone;

-- Convert saledate column to standard date format
alter table nashvilleclone
add salesdate date;

update nashvilleclone
set salesdate = convert(saledate,date);
select saledate,salesdate from nashvilleclone;

alter table nashvilleclone
drop SaleDate;
select * from nashvilleclone;

-- Update soldasvacant column: change 'N' to 'No' and 'Y' to 'Yes'
select distinct(soldasvacant), count(soldasvacant) as count
from nashvilleclone
group by SoldAsVacant
order by count desc;

update nashvilleclone
set soldasvacant =
	case soldasvacant
		when 'N' then 'No'
        when 'Y' then 'Yes'
	end
where soldasvacant not in ('No','Yes');
select distinct(SoldAsVacant),count(SoldAsVacant) as Frequency 
from nashvilleclone
group by SoldAsVacant;

-- Update propertyaddress column: fill in missing address
select a.uniqueid,a.parcelid,a.propertyaddress,
	b.uniqueid,b.parcelid,b.propertyaddress
from nashvilleclone as a
join nashvilleclone as b
on a.parcelid = b.parcelid and a.uniqueid <> b.uniqueid
where a.propertyaddress is null;

update nashvilleclone as a
join nashvilleclone as b
on a.uniqueid <> b.uniqueid and a.parcelid = b.parcelid
set a.propertyaddress = ifnull(a.propertyaddress,b.propertyaddress)
where a.propertyaddress is null;
select propertyaddress from nashvilleclone
where PropertyAddress is null;

-- Break propertyaddress column into address and city columns
alter table nashvilleclone
add propertycity varchar(100);

update nashvilleclone
set propertycity = frstring_parser(propertyaddress,',',1),
	propertyaddress = frstring_parser(propertyaddress,',',-1);
select propertyaddress,propertycity from nashvilleclone;

-- Update owneraddress column: fill in missing address
select a.uniqueid,a.parcelid,a.propertyaddress,
	b.uniqueid,b.parcelid,b.propertyaddress
from nashvilleclone as a
join nashvilleclone as b
on a.parcelid = b.parcelid and a.uniqueid <> b.uniqueid
where a.propertyaddress is null;

update nashvilleclone as a
join nashvilleclone as b
on a.uniqueid <> b.uniqueid and a.parcelid = b.parcelid
set a.propertyaddress = ifnull(a.propertyaddress,b.propertyaddress)
where a.propertyaddress is null;

-- Break owneraddress column into address, city and state columns.
-- Fill null records with 'Not provided'
alter table nashvilleclone
add ownercity varchar(100),
add ownerstate varchar(30);

update nashvilleclone
set ownerstate = ifnull(frstring_parser(owneraddress,',',1),'Not provided'),
	ownercity = ifnull(frstring_parser(owneraddress,',',2),'Not provided'),
	owneraddress = ifnull(frstring_parser(owneraddress,',',3),'Not provided');
select distinct(owneraddress),ownercity,ownerstate from nashvilleclone;

-- View duplicate records
with nashvilleCTE as (
select *,row_number()
over(partition by parcelid,landuse,propertyaddress,propertycity,legalreference,saleprice,salesdate order by parcelid) as dup
from nashvilleclone)
select * from nashvilleCTE
where dup > 1
order by dup desc;

-- Add a column for building age and remove duplicate records
alter table nashvilleclone
modify column uniqueid varchar(100) not null,
add primary key (uniqueid),
add duplicaterows int,
add buildingage int;

drop table if exists nashvilleTEMP;
create temporary table nashvilleTEMP as (
	select 
		uniqueid,
		row_number() over(
			partition by parcelid,landuse,propertyaddress,propertycity,legalreference,saleprice,salesdate 
			order by parcelid
		) as dup
	from nashvilleclone
);
update nashvilleclone as C
join nashvilleTEMP as T
on C.uniqueid = T.uniqueid
set C.duplicaterows = T.dup;

update nashvilleclone 
set buildingage = (year(curdate()) - YearBuilt);

delete from nashvilleclone
where duplicaterows > 1;

-- Check for inconsistencies in land use column
select distinct(landuse) as Typee,bedrooms as BR, count(PropertyAddress) as Num
from nashvilleclone
where bedrooms > 0
group by landuse, Bedrooms
order by BR desc;

update nashvilleclone
-- set landuse = 'VACANT RESIDENTIAL LAND'
-- where landuse = 'VACANT RES LAND';
set landuse = 'GREENBELT'
where landuse like '%/RES_x%';

-- Remove Unused Columns
alter table nashvilleclone
drop ownername,
drop owneraddress,
drop acreage,
drop taxdistrict,
drop duplicaterows;

/* Data Analysis:
	1. Total number of properties by:
		i. City
        ii. Land use
        iii Total value range
        iv. Building age range
        v. Number of bedrooms
        vi. Year sold
	
    2.	Unassessed Properties by city, age, land use, facilities
    3.	Valued Properties by city, age, land use, facilities, land value, building value, total value
    4. 	Properties grouped by city,age,land use,facilities (number of bedrooms,fullbaths and halfbaths) 
		average total value, average sale price and average profit
*/

-- AGGREGATES
-- Total number of properties by city
-- drop view Total_number_of_properties_by_city;
create view Total_number_of_properties_by_city as (
	select distinct(propertycity) as City,count(PropertyAddress) as 'Number of Properties'
	from nashvilleclone
	group by propertycity);
select * from Total_number_of_properties_by_city;

-- Total number of properties by land use
-- drop view Total_number_of_properties_by_LandUse;
create view Total_number_of_properties_by_LandUse as (
	select distinct(landuse) as 'Land Use',count(PropertyAddress) as 'Number of Properties'
	from nashvilleclone
	group by landuse);
select * from Total_number_of_properties_by_LandUse;

-- Total number of properties by total value range
-- drop view Total_number_of_properties_by_TotalValueRange;
create view Total_number_of_properties_by_TotalValueRange as (
	select 'Number of Properties' as 'Total Value Range',
		count(PropertyAddress) as '$1M above',
			(select count(PropertyAddress) 
				from nashvilleclone
                where TotalValue between 500000 and 999999) as '$500K - $1M',
                (select count(PropertyAddress) 
					from nashvilleclone
					where TotalValue between 100000 and 499999) as '$100K - $500K',
                    (select count(PropertyAddress) 
						from nashvilleclone
						where TotalValue between 20000 and 99999) as '$20K - $100K',
                        (select count(PropertyAddress) 
							from nashvilleclone
							where TotalValue < 20000) as '$20K below',
                            (select count(PropertyAddress) 
								from nashvilleclone
								where TotalValue is null) as 'Unassessed'
	from nashvilleclone
    where TotalValue > 1000000);
select * from Total_number_of_properties_by_TotalValueRange;

-- Total number of properties by land use and bedrooms
create view Total_number_of_properties_by_LandUse_and_Bedrooms as (
	select distinct(landuse) as 'Property type',bedrooms as 'Number of Bedrooms', count(PropertyAddress) as Num
	from nashvilleclone
	where bedrooms > 0
	group by landuse, bedrooms
	order by bedrooms desc);
    select * from Total_number_of_properties_by_LandUse_and_Bedrooms;

-- Total number of properties by building age range
-- drop view Total_number_of_properties_by_BuildingAgeRange;
create view Total_number_of_properties_by_BuildingAgeRange as (
	select 'Number of Properties' as 'Age Range (Years)',
		count(PropertyAddress) as '200 years and above',
			(select count(PropertyAddress) 
				from nashvilleclone
                where buildingage between 100 and 200) as '100 - 199 Years',
                (select count(PropertyAddress) 
					from nashvilleclone
					where buildingage between 50 and 99) as '50 - 99 Years',
                    (select count(PropertyAddress) 
						from nashvilleclone
						where buildingage between 11 and 49) as '11 - 50 Years',
                        (select count(PropertyAddress) 
							from nashvilleclone
							where buildingage < 11) as '10 Years and below'
	from nashvilleclone
    where buildingage > 200);
select * from Total_number_of_properties_by_BuildingAgeRange;

-- Properties sold yearly by type, building age and Number of rooms
create view Properties_sold_yearly_by_TypeAge as (
	select distinct(year(salesdate)) as Year,landuse as 'Property type',bedrooms as 'Number of Rooms',
		buildingage as 'Building Age',count(propertyaddress) as 'Number of Properties',
		round(avg(totalvalue),2) as 'Average Total Value',round(avg(saleprice),2) as 'Average Sale Price',propertycity as City
	from nashvilleclone
	where landuse like '%COMBO%'
	-- where landuse = 'SINGLE FAMILY'
	group by Year,landuse,propertycity,bedrooms,buildingage
	order by Year desc);
    select * from Properties_sold_yearly_by_TypeAge;

-- View of all city where nashville has properties ranked by average property value and average sale price
-- Give an idea of where nashville operations are more profitable
-- drop view avg_property_value_by_city;
create view avg_property_value_by_city as (
	select distinct(propertycity) as City,count(propertyaddress) as 'Number of Properties',
		round(avg(totalvalue),2) as 'Average Value',round(avg(SalePrice),2) 'Average Sale Price',
        round((avg(SalePrice) - avg(TotalValue))) as 'Average Profit'
	from nashvilleclone
	group by propertycity
	order by avg(totalvalue) desc);
select * from avg_property_value_by_city;

-- View of all properties still awaiting valuation grouped by city
-- drop view Properties_awaiting_valuation_by_city;
create view Properties_awaiting_valuation_by_city as (
	select distinct(propertycity) as City,count(PropertyAddress) 'Number of properties'
	from nashvilleclone
	where TotalValue is null
	group by propertycity);
select * from Properties_awaiting_valuation_by_city;
 
 select * from nashvilleclone;

