1.В каких городах больше одного аэропорта? 
	* Использовала функцию count в значении больше 1, как условие для выведения результата.
select a.city, count (airport_code) as airports_quantity
from airports a
group by a.city
having count (airport_code) > 1;

2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета? (Подзапрос)
	* Использовала два join для соединения таблиц аэропрорты-рейсы-самолеты, 
	далее подзапрос для нахождения самолетов с максимальной дальностью и группировку по аэропортам и дальности.

select a.airport_name, a2.range 
from airports a
join flights f on f.departure_airport = a.airport_code 
join aircrafts a2 on f.aircraft_code = a2.aircraft_code 
where a2.range = (select max(a2.range) from aircrafts a2)
group by a.airport_name, a2.range;

3. Вывести 10 рейсов с максимальным временем задержки вылета. (Оператор limit)
	* Использовала функцию age для вычисления разности между план/факт временем вылета,
	добавила сортировку по этому параметру по убыванию и лимит 10 рейсов, также добавила ему условие "не равно нулю",
	так как сортировка сначала выдает рейсы с null. 

select f.flight_id, f.departure_airport, age (f.actual_departure, f.scheduled_departure) as delayed
from flights f
where age (f.actual_departure, f.scheduled_departure) is not null
order by delayed desc
limit 10;

4. Были ли брони, по которым не были получены посадочные талоны? (Верный тип join)
	* Использовала inner join для соединения таблиц брони-билеты, 
	далее left join - чтобы вывести только те брони, у которых нет посадочных талонов.
	Добавила distinct в выборку, чтобы не возвращались несколько раз брони, где было несколько билетов.

 select distinct b.book_ref, bp.boarding_no 
 from bookings b 
 join tickets t on b.book_ref = t.book_ref 
 left join boarding_passes bp on t.ticket_no =bp.ticket_no 
 where bp.boarding_no is null;

5. Найдите свободные места для каждого рейса, их % отношение к общему количеству мест в самолете.
(Оконная функция и Подзапросы)
	* Сначала добавила столбец с накопительным итогом - суммарное количество вывезенных пассажиров из аэропорта за день.

select f.flight_id as "id рейса", 
	f.aircraft_code as "Код самолета", 
	f.departure_airport as "Код аэропорта", 
	date(f.actual_departure) as "Дата вылета",
	(s.count_seats - bp.count_bp) as "Свободные места",
	round((cast(bp.count_bp as numeric) * 100 / s.count_seats), 2) as "% от общего количества мест",
	sum(bp.count_bp) over (partition by date(f.actual_departure), f.departure_airport order by f.actual_departure) as "Накопительная",
	bp.count_bp as "Количество вылетевших пассажиров"
from flights f
left join (
	select bp.flight_id, count(bp.seat_no) as count_bp
	from boarding_passes bp
	group by bp.flight_id
	order by bp.flight_id) as bp on bp.flight_id = f.flight_id 
left join (
	select s.aircraft_code, count(*) as count_seats
	from seats s 
	group by s.aircraft_code) as s on f.aircraft_code = s.aircraft_code
where f.actual_departure is not null and bp.count_bp is not null
order by date(f.actual_departure)

* Далее посчитала процентное соотношение перелетов по типам самолетов от общего количества.

select aircrafts.model as "Модель самолета", aircrafts.aircraft_code, 
round((count(flights.flight_id)::numeric)*100 / (select count(flights.flight_id) from flights)::numeric, 2) as "Доля перелетов"
from aircrafts
full outer join flights on aircrafts.aircraft_code = flights.aircraft_code
group by aircrafts.aircraft_code
order by "Доля перелетов" desc;

6. Найдите процентное соотношение перелетов по типам самолетов от общего количества. (Подзапрос и Оператор ROUND)
	* Использовала подзапрос для вычисления общего кол-ва перелетов, join для соединения таблиц самолеты-рейсы,
	оператор round для приведения результата к плавающему числу с 2 цифрами после запятой.
	Так как кол-во перелетов - целые числа, привела их к типу decimal, далее сгруппировала по моделям самолетов и 
	отсортировала для наглядности по убыванию кол-ва перелетов.

select a.model, count(f.flight_id) as flights, 
round (count(f.flight_id)::decimal / ((select count(f.flight_id) from flights f)::decimal)*100, 2) as percent_in_total 
from aircrafts a 
join flights f on a.aircraft_code = f.aircraft_code
group by a.model
order by flights desc; 

7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета? (СТЕ)
	* Создала 2 СТЕ (первое для эконома, второе для бизнес-класса), далее при помощи функции join соединила их по номеру рейса
	и задала условие вывести те города, где стоимость билета в рамках одного перелета в эконом-классе была больше, чем в бизнесе.
	
with cte_1 as (
select f.flight_id, a.city, tf.fare_conditions, tf.amount 
from airports a 
join flights f on a.airport_code = f.arrival_airport 
join ticket_flights tf on f.flight_id = tf.flight_id
where tf.fare_conditions = 'Economy'
group by f.flight_id, a.city, tf.fare_conditions, tf.amount
), 
	cte_2 as (
	select f.flight_id, a.city, tf.fare_conditions, tf.amount 
	from airports a 
	join flights f on a.airport_code = f.arrival_airport 
	join ticket_flights tf on f.flight_id = tf.flight_id
	where tf.fare_conditions = 'Business'
	group by f.flight_id, a.city, tf.fare_conditions, tf.amount
)
select cte_1.city 
from cte_1
join cte_2 on cte_1.flight_id = cte_2.flight_id
where cte_1.amount > cte_2.amount
group by cte_1.city; 

8. Между какими городами нет прямых рейсов? 
(Декартово произведение в предложении from, Самостоятельно созданные представления, Оператор except)
	* Создала представления с названиями городов вылета и прилета соответственно из таблицы рейсов.
	
create view route as 
	select distinct a.city as departure_city , b.city as arrival_city, a.city||'-'||b.city as route 
	from airports as a, (select city from airports) as b
	where a.city != b.city
	--where a.city > b.city если хотим убрать зеркальные варианты
	order by route
	
create view direct_flight as 
	select distinct a.city as departure_city, aa.city as arrival_city, a.city||'-'|| aa.city as route  
	from flights as f
	inner join airports as a on f.departure_airport=a.airport_code
	inner join airports as aa on f.arrival_airport=aa.airport_code
	order by route
	
select r.* 
from route as r
except 
select df.* 
from direct_flight as df

9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов в самолетах, обслуживающих эти рейсы.
(Оператор RADIANS или использование sind/cosd)
	* Создала 3 сте: первая - для выборки координат а/п вылета, вторая - для координат а/п прилета,
	третья - для расчета d — расстояния между пунктами в радианах.
	Далее соединила полученную сте_3 с таблицей рейсов и вывела аэропорты, между которыми есть прямые рейсы и 
	подсчитала расстояние между ними в км, округлила полученное значение до целого числа,
	и соединила с таблицей самолеты для добавления информации по допустимой дальности перелетов.
	
with cte_1 as (
	select f.flight_no, f.departure_airport, a.latitude, a.longitude 
	from flights f
	join airports a on f.departure_airport = a.airport_code 
	group by f.flight_no, f.departure_airport, a.latitude, a.longitude),
 		cte_2 as (
 		select f.flight_no, f.arrival_airport, a.latitude, a.longitude 
		from flights f
		join airports a on f.arrival_airport = a.airport_code 
		group by f.flight_no, f.arrival_airport, a.latitude, a.longitude),
			cte_3 as (
			select cte_1.flight_no, 
			acos (sind (cte_1.latitude) * sind (cte_2.latitude) + cosd (cte_1.latitude) * cosd (cte_2.latitude) * cosd (cte_1.longitude - cte_2.longitude))::decimal as d
			from cte_1
			join cte_2 on cte_1.flight_no = cte_2.flight_no
			group by cte_1.flight_no, cte_1.latitude, cte_2.latitude, cte_1.longitude, cte_2.longitude)
select f.departure_airport, f.arrival_airport, round (cte_3.d * 6371, 0) as distance_km, a.range as permissible_max_range 
from cte_3
join flights f on cte_3.flight_no = f.flight_no
join aircrafts a on f.aircraft_code = a.aircraft_code 
group by f.departure_airport, f.arrival_airport, cte_3.d, a.range;
		

