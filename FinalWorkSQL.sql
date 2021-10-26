1. В каких городах больше одного аэропорта? 
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
	* Сначала создала 2 сте: в первой посчитала кол-во мест в самолете на каждый выполненный рейс, 
	во второй - кол-во занятых мест на каждый рейс, потом соединила их с помощью join
	для расчета кол-ва свободных мест и % к общему кол-ву мест в самолете .

with cte_1 as 
	(select f.flight_id, s.aircraft_code, count (s.seat_no) as total_seats
	from flights f
	join seats s on f.aircraft_code = s.aircraft_code 
	group by f.flight_id, s.aircraft_code),
     	cte_2 as 
     	(select bp.flight_id, count (bp.boarding_no) as occup_seats
     	from boarding_passes bp
     	group by bp.flight_id)
select cte_1.flight_id, cte_1.aircraft_code, cte_1.total_seats - cte_2.occup_seats as free_seats, 
round ((cte_1.total_seats - cte_2.occup_seats)::decimal / cte_1.total_seats::decimal *100, 2) as percent_in_total_seats
from cte_1
join cte_2 on cte_1.flight_id = cte_2.flight_id;

	* Для расчета накопительного итога пыталась создать оконную функцию, но получается какая-то ерунда.
	И как это все соединить подзапросом - увы, ума не приложу, моих знаний не хватает.

select f.flight_id, f.departure_airport, f.actual_departure::date,
count (bp.seat_no) over (partition by f.departure_airport, f.actual_departure order by f.departure_airport)
from flights f 
join boarding_passes bp on f.flight_id = bp.flight_id
order by f.departure_airport; 

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
	* Создала 2 сте (первое для эконома, второе для бизнес-класса), далее при помощи функции join соединила их по номеру рейса
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
	* Создала представления dpt_cities и arv_cities с названиями городов вылета и прилета соответственно из таблицы рейсов.

create view dpt_cities as 
(select f.flight_id, a.city, f.departure_airport, f.arrival_airport 
from airports a
join flights f on a.airport_code = f.departure_airport 
group by f.flight_id, a.city);

create view arv_cities as
(select f.flight_id, a.city, f.departure_airport, f.arrival_airport 
from airports a
join flights f on a.airport_code = f.arrival_airport  
group by f.flight_id, a.city);

	* Далее пыталась хоть что-то придумать с оператором except и декартовым произведением, изучила все форумы в инете,
	но на все мои попытки dbeaver зависает, т.к. я его заставляю считать какую-то несовместимую бессмыслицу.

select dpt_cities.city, arv_cities.city 
from dpt_cities, arv_cities
group by dpt_cities.city, arv_cities.city


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
		

