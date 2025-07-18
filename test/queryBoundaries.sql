select country_name_en, americas, europe, russia_middle_east, asia_oceania
from countries
order by americas nulls last, europe nulls last,
 russia_middle_east nulls last, asia_oceania nulls last;

-- The most iterations to find an area.
select iter, country_name_en, count(1)
from tries t
join countries c
on (t.id_country = c.country_id)
group by iter, country_name_en
order by iter desc, count(1) desc;

-- Details of the iteration.

select t.*, country_name_en
from tries t
join countries c
on (t.id_country = c.country_id)
where iter = 121;

-- How many iterations per region to find the appropriate area.
-- This allows to reorganize the updates of the organizeAreas function.

select iter, count(1), area, country_name_en
from tries t
join countries c
on t.id_country = c.country_id
group by iter, area, country_name_en
order by area, count(1) desc;
