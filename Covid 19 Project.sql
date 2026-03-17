--SELECT TOP (1000) [Entity]
--      ,[Code]
--      ,[Day]
--      ,[Vaccine doses (per 100)]
--      ,[Share of people with at least one dose]
--      ,[Share of people with a complete initial protocol]
--      ,[Booster doses (per 100)]
--  FROM [Covid Death Portfolio Project].[dbo].[covid-19-vaccine-doses]

--SELECT TOP (1000) [Entity]
--      ,[Code]
--      ,[Day]
--      ,[Total confirmed deaths due to COVID-19 per million people]
--  FROM [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people]

--SELECT TOP (1000) [Entity]
--      ,[Code]
--      ,[Day]
--      ,["Daily new confirmed deaths due to COVID-19 per million people (rolling 7-day average]
--      ,[ right-aligned)"]
--  FROM [Covid Death Portfolio Project].[dbo].[daily-new-confirmed-covid-19-deaths-per-million-people]

--Looking At Survival Rate
  
   --Looking at Vacines doses vs Total Deaths
   ----shows likelihood of surviving covid in your country
   Select TRY_CAST(C.[Total confirmed deaths due to COVID-19 per million people] AS FLOAT), C.Entity, C.Day, TRY_CAST (P.[Vaccine doses (per 100)] AS FLOAT), TRY_CAST (P.[Vaccine doses (per 100)] AS FLOAT)/NULLIF(TRY_CAST(C.[Total confirmed deaths due to COVID-19 per million people] AS FLOAT), 0) * 100 AS SURVIVALRATE
   FROM [Covid Death Portfolio Project].[dbo].[covid-19-vaccine-doses] AS P
   JOIN [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people] AS C
   ON P.ENTITY = C.ENTITY
   Where P.Entity like 'nigeria'
   Order by 2,3

   --Looking at Countries with Highest use of Vaccines
   Select Entity, DAY, MAX([Vaccine doses (per 100)]) AS HIGHESTVACCINEDOSES
   FROM [Covid Death Portfolio Project].[dbo].[covid-19-vaccine-doses]
   GROUP BY ENTITY, Day
   ORDER BY 3 DESC

   --LOOKING AT COUNTRIES WITH HIGHEST DEATH COUNT
   Select Entity, DAY, MAX([Total confirmed deaths due to COVID-19 per million people]) AS HIGHESTDEATHRATE
   FROM [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people]
   GROUP BY ENTITY, Day
   ORDER BY 3 DESC

   --LETS BREAK THINGS DOWN BY CONTINENT
   Select Entity, DAY, MAX([Total confirmed deaths due to COVID-19 per million people]) AS HIGHESTDEATHRATE
   FROM [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people]
   WHERE Entity IN ('Africa', 'Europe', 'North America', 'Asia', 'South America')
   GROUP BY ENTITY, Day
   ORDER BY 3 DESC

   --GLOBAL NUMBERS
   SELECT Entity, Day, SUM(Cast(["Daily new confirmed deaths due to COVID-19 per million people (rolling 7-day average] AS FLOAT))
   FROM [Covid Death Portfolio Project].[dbo].[daily-new-confirmed-covid-19-deaths-per-million-people]
   WHERE Entity IN ('Africa', 'Europe', 'North America', 'Asia', 'South America')
   GROUP BY ENTITY, Day
   ORDER BY 3 DESC


   --TOTAL DEATHS
   SELECT SUM(Cast(["Daily new confirmed deaths due to COVID-19 per million people (rolling 7-day average] AS FLOAT))
   FROM [Covid Death Portfolio Project].[dbo].[daily-new-confirmed-covid-19-deaths-per-million-people]
   WHERE Entity IN ('Africa', 'Europe', 'North America', 'Asia', 'South America')
   --GROUP BY ENTITY, Day
   --ORDER BY 3 DESC


--Vaccinatio Vs deaths by region
   Select P.DAY, C.[Total confirmed deaths due to COVID-19 per million people], C.Entity, P.[Vaccine doses (per 100)], Sum(Cast(P.[Vaccine doses (per 100)] AS float)) OVER (Partition by C.Entity) AS Rollingvaccinedoses 
   FROM [Covid Death Portfolio Project].[dbo].[covid-19-vaccine-doses] AS P
   JOIN [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people] AS C
   ON P.ENTITY = C.ENTITY
   AND P.Day = C.DAY
   Where P.Entity IN ('Africa', 'Europe', 'North America', 'Asia', 'South America', 'Australia')
   Order by 2,3


--Using Convert instead of Cast
   Select P.DAY, C.[Total confirmed deaths due to COVID-19 per million people], C.Entity, P.[Vaccine doses (per 100)], Sum(Convert(float,P.[Vaccine doses (per 100)])) OVER (Partition by C.Entity) AS Rollingvaccinedoses 
   FROM [Covid Death Portfolio Project].[dbo].[covid-19-vaccine-doses] AS P
   JOIN [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people] AS C
   ON P.ENTITY = C.ENTITY
   AND P.Day = C.DAY
   Where P.Entity IN ('Africa', 'Europe', 'North America', 'Asia', 'South America', 'Australia')
   Order by P.Entity, P.Day



   --Using CTE
   With VacEnt (Entity,[Vaccine doses (per 100)], Day, [Total confirmed deaths due to COVID-19 per million people], Rollingvaccinedoses )
   as
   (
   Select P.DAY, C.[Total confirmed deaths due to COVID-19 per million people], C.Entity, P.[Vaccine doses (per 100)], Sum(Convert(float,P.[Vaccine doses (per 100)])) OVER (Partition by C.Entity) AS Rollingvaccinedoses 
   FROM [Covid Death Portfolio Project].[dbo].[covid-19-vaccine-doses] AS P
   JOIN [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people] AS C
   ON P.ENTITY = C.ENTITY
   AND P.Day = C.DAY
   Where P.Entity IN ('Africa', 'Europe', 'North America', 'Asia', 'South America', 'Australia')
   --Order by P.Entity, P.Day
   )
   Select *
   From VacEnt




   --Temp...Table
   Drop table if exists #Vaccinatedpeople
   Create Table #Vaccinatedpeople
   (
   Entity nvarchar(255),
   Day datetime,
   [Total confirmed deaths due to COVID-19 per million people] FLOAT,
   [Vaccine doses (per 100)] FLOAT,
   Rollingvaccinedoses FLOAT
   )

   Insert Into #Vaccinatedpeople
   Select C.Entity, P.DAY, C.[Total confirmed deaths due to COVID-19 per million people], P.[Vaccine doses (per 100)], Sum(Convert(float,P.[Vaccine doses (per 100)])) OVER (Partition by C.Entity) AS Rollingvaccinedoses 
   FROM [Covid Death Portfolio Project].[dbo].[covid-19-vaccine-doses] AS P
   JOIN [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people] AS C
   ON P.ENTITY = C.ENTITY
   AND P.Day = C.DAY
   Where P.Entity IN ('Africa', 'Europe', 'North America', 'Asia', 'South America', 'Australia')
   --Order by P.Entity, P.Day

   --Create view to store data later for visualisation
   Create view Vaccinatedpeople as
   Select C.Entity, P.DAY, C.[Total confirmed deaths due to COVID-19 per million people], P.[Vaccine doses (per 100)], Sum(Convert(float,P.[Vaccine doses (per 100)])) OVER (Partition by C.Entity) AS Rollingvaccinedoses 
   FROM [Covid Death Portfolio Project].[dbo].[covid-19-vaccine-doses] AS P
   JOIN [Covid Death Portfolio Project].[dbo].[cumulative-confirmed-covid-19-deaths-per-million-people] AS C
   ON P.ENTITY = C.ENTITY
   AND P.Day = C.DAY
   Where P.Entity IN ('Africa', 'Europe', 'North America', 'Asia', 'South America', 'Australia')
   --Order by P.Entity, P.Day
