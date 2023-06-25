-- Задание 1. Выведите названия самолётов, которые имеют менее 50 посадочных мест.

select a.aircraft_code, a.model ,count(s.seat_no) 
from aircrafts a 
left join seats s on s.aircraft_code = a.aircraft_code 
group by a.aircraft_code, a.model 
having count(s.seat_no) < 50


--Задание 2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

select t.date_trunc, t.sum, round(((t.sum - lag(t.sum, 1, 0.) over (order by t.date_trunc))/ 
									lag(t.sum, 1) over (order by t.date_trunc))*100,2)
from (
	select date_trunc('month', b.book_date), sum(b.total_amount)   
	from bookings b
	group by 1 
	order by 1) t

-- Задание 3. Выведите названия самолётов без бизнес-класса. Используйте в решении функцию array_agg.

select a.model 
from (
	select s.aircraft_code, array_agg(fare_conditions) 
	from seats s 
	group by 1
	having array_position(array_agg(fare_conditions), 'Business') is null) t
left join aircrafts a on a.aircraft_code = t.aircraft_code

/**Задание 4. Выведите накопительный итог количества мест в самолётах по каждому аэропорту на каждый день. 
	Учтите только те самолеты, которые летали пустыми и только те дни, когда из одного аэропорта вылетело более одного такого самолёта.
	Выведите в результат код аэропорта, дату вылета, количество пустых мест и накопительный итог.**/
		   
select t.departure_airport, t.actual_departure, t.count, t.sum
from(
	select t.actual_departure, t.departure_airport, t.aircraft_code, s.count,
		   count(t.aircraft_code) over (partition by t.actual_departure, t.departure_airport) count_of_boards,
		   sum(s.count) over (partition by t.actual_departure, t.departure_airport rows between unbounded preceding and current row)
	from (
		select date_trunc('day', f.actual_departure) as actual_departure,
			 f.departure_airport,
			 f.aircraft_code
		from flights f
		left join boarding_passes bp on bp.flight_id = f.flight_id
		where bp.boarding_no is null and (f.status = 'Departed' or f.status = 'Arrived')
		group by 1,2,3) t
	left join (select aircraft_code, count(seat_no)
			   from seats s 
			   group by aircraft_code) s on s.aircraft_code = t.aircraft_code		
	order by 1,2) t 
where count_of_boards > 1	


/** Задание 5.
 * Найдите процентное соотношение перелётов по маршрутам от общего количества перелётов. 
 * Выведите в результат названия аэропортов и процентное отношение.
   Используйте в решении оконную функцию.

 */

select t.departure_airport, t.arrival_airport, round((t.count/t.sum)*100,4) as "share of flights"
from (
	select *, f.departure_airport, f.arrival_airport, count(*), sum(count(*)) over ()
	from flights f
	left join airports a on a.airport_code = f.departure_airport 
	group by 1,2
	order by 1) t


/** Задание 6.
 * Выведите количество пассажиров по каждому коду сотового оператора. Код оператора – это три символа после +7
 **/

select substring(contact_data ->> 'phone' from 3 for 3), count(t.passenger_id) 
from tickets t
group by 1
order by 1
	
	
	
/** Задание 7.
 * Классифицируйте финансовые обороты (сумму стоимости билетов) по маршрутам:
	до 50 млн – low
	от 50 млн включительно до 150 млн – middle
	от 150 млн включительно – high
Выведите в результат количество маршрутов в каждом полученном классе.
 */	
	
select tf.class_amount, count(tf.class_amount) 
from (
select case 
			when t.sum < 50000000 then 'low'
			when t.sum between 50000000 and 150000000 then 'middle'
			else 'high'
		end class_amount
from (
	select f.departure_airport, f.arrival_airport, sum(tf.amount)
	from flights f 
	left join ticket_flights tf on tf.flight_id = f.flight_id 
	group by 1,2
	order by 1) t
where t.sum is not null) tf 
group by 1

/** Задание 8.
Вычислите медиану стоимости билетов, медиану стоимости бронирования и 
	отношение медианы бронирования к медиане стоимости билетов,
 		результат округлите до сотых. 
 */	

select distinct percentile_cont(0.5) within group (order by tf.amount) as "Медиана стоимости билета", 
				percentile_cont(0.5) within group (order by b.total_amount) as "Медиана стоимости бронирования", 
				round(((percentile_cont(0.5) within group (order by b.total_amount))/(percentile_cont(0.5) within group (order by tf.amount)))::numeric, 2)
from tickets t 
left join ticket_flights tf on tf.ticket_no = t.ticket_no 
left join bookings b on b.book_ref = t.book_ref 



/**Задание 9.
 * Найдите значение минимальной стоимости одного километра полёта для пассажира. 
 * Для этого определите расстояние между аэропортами и учтите стоимость билетов.

Для поиска расстояния между двумя точками на поверхности Земли используйте дополнительный модуль earthdistance. 
Для работы данного модуля нужно установить ещё один модуль – cube.

Важно: 
*  Установка дополнительных модулей происходит через оператор CREATE EXTENSION название_модуля.
*  В облачной базе данных модули уже установлены.
*  Функция earth_distance возвращает результат в метрах.*/

create extension cube
create extension earthdistance

select t.departure_airport, t.arrival_airport, round((t.min/t.distance),2) as "Min стоимость 1 км. по маршруту", 
		min(round((t.min/t.distance),2)) over () as "Наименьшая стоимость 1 км."
from (
	select t.departure_airport, t.dep_lot, t.dep_lat, t.arrival_airport, a.longitude, a.latitude, t.min,
		   (earth_distance (ll_to_earth (t.dep_lat, t.dep_lot), ll_to_earth (a.latitude, a.longitude))::int)/1000 as distance
	from (
		select t.departure_airport, a.longitude as dep_lot, a.latitude as dep_lat, t.arrival_airport, t.min
		from (
			select f.departure_airport, f.arrival_airport, min(tf.amount)
			from flights f 
			left join ticket_flights tf on tf.flight_id = f.flight_id
			group by 1,2) t
		left join airports a on a.airport_code = t.departure_airport) t 
	left join airports a on a.airport_code = t.arrival_airport
	where t.min is not null) t 
order by 3