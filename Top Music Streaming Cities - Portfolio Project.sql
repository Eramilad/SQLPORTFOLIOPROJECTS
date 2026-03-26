SELECT TOP (1000) [stream_id]
      ,[stream_date]
      ,[city]
      ,[country]
      ,[subregion]
      ,[platform]
      ,[genre]
      ,[content_language]
      ,[artist_tier]
      ,[subscription_type]
      ,[device_type]
      ,[monthly_streams]
      ,[avg_track_duration_min]
      ,[skip_rate]
      ,[track_completion_rate]
      ,[revenue_usd]
  FROM [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[Streaming Info - Top Music Streaming Cities in Africa - Sheet1]



  SELECT TOP (1000) [stream_id]
      ,[stream_date]
      ,[city]
      ,[country]
      ,[subregion]
      ,[age_group]
      ,[city_population_mil]
      ,[internet_penetration_pct]
      ,[mobile_share_pct]
      ,[gdp_per_capita_usd]
  FROM [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]


  --Let's See The Cities With The Highest Streams,revenue,population.
  --Streams
  Select [city],[country],[subregion],
  SUM (TRY_CAST ([monthly_streams] AS BIGINT)) AS [TOTALMONTHLYSTREAMS]
  From [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[Streaming Info - Top Music Streaming Cities in Africa - Sheet1]
  Group by [city],[country],[subregion]
  ORDER BY [TOTALMONTHLYSTREAMS] DESC


  --Revenue
  Select [city],[country],[subregion],
  SUM (TRY_CAST ([revenue_usd] AS decimal(18,2))) AS [TOTALMONTHLYREVENUEUSD]
  From [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[Streaming Info - Top Music Streaming Cities in Africa - Sheet1]
  Group by [city],[country],[subregion]
  ORDER BY [TOTALMONTHLYREVENUEUSD] DESC


  --POPULATION
  Select [city],[country],[subregion],
  SUM (TRY_CAST ([city_population_mil] AS decimal(18,2))) AS [TOTALCITYPOPULATIONMIL]
  From [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
  Group by [city],[country],[subregion]
  ORDER BY [TOTALCITYPOPULATIONMIL] DESC




  --Lets see the Genre with the Highest Streams, the Genre Making the Most Money.

  Select [genre],
  SUM (TRY_CAST ([monthly_streams] AS BIGINT)) AS [TOTALSTREAMS]
  From [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[Streaming Info - Top Music Streaming Cities in Africa - Sheet1]
  Group by [genre]
  ORDER BY [TOTALSTREAMS] DESC


  --Genre Making the Most Money.
  Select [genre],
  SUM (TRY_CAST ([revenue_usd] AS decimal(18,2))) AS [TOTALGENREREVENUES]
  From [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[Streaming Info - Top Music Streaming Cities in Africa - Sheet1]
  Group by [genre]
  ORDER BY [TOTALGENREREVENUES] DESC



  --Let's see the relationship beteewn age groups and genre.

--Using Count
Select S.[genre], C.age_group,
Count(*) As TotalListeners
  From [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[Streaming Info - Top Music Streaming Cities in Africa - Sheet1] AS S
  JOIN [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1] AS C
  ON S.city = C.city
  Group by S.[genre], C.age_group
  ORDER BY TotalListeners DESC

  --Using Case Statement 
Select S.[genre],
AVG(Case C.[age_group]
    When '18-24' THEN 21
    When '25-34' THEN 29
    When '35-44' THEN 39
    When '45-54' Then 49
    When '55+' Then 60
    END) AS AVGAGEPERGENRE
  From [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[Streaming Info - Top Music Streaming Cities in Africa - Sheet1] AS S
  JOIN [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1] AS C
  ON S.city = C.city
  Group by S.[genre]
  ORDER BY AVGAGEPERGENRE DESC



  --Using Temp Tables
  Drop Table If Exists #Citystreamingsummary;
  SELECT C.[city],C.[country],C.[subregion],
  MAX(TRY_CAST(C.[city_population_mil] AS DECIMAL(18,2))) AS [city_population_mil],
  MAX(TRY_CAST(REPLACE(REPLACE(REPLACE(C.[gdp_per_capita_usd]
  ,',','')
  ,'%','')
  ,' ','')
  AS DECIMAL(18,2))) AS [gdp_per_capita_usd],
  COUNT(*) AS [TOTALRECORDS],
  SUM(TRY_CAST(S.[monthly_streams] AS bigint)) AS [TOTALSTREAMS],
  SUM(TRY_CAST(S.[revenue_usd] AS decimal(18,2))) AS [TOTALREVENUE],
  AVG(TRY_CAST(REPLACE(S.[skip_rate],'%','') AS DECIMAL(18,2))) AS [AVGskiprate]
  INTO #CityStreamingSummary
  FROM [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1] AS C
  JOIN [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[Streaming Info - Top Music Streaming Cities in Africa - Sheet1] AS S
  ON UPPER(TRIM(C.country)) = UPPER(TRIM(S.country))
  GROUP BY C.[city],C.[country],C.[subregion];


  SELECT *
  FROM #CityStreamingSummary

  --Does Higher GDP Mean More Streams
  Select [gdp_per_capita_usd],[TOTALSTREAMS],[city],[country]
  FROM #CityStreamingSummary
  ORDER BY [TOTALREVENUE] DESC

  --Which Cities have high streams but low revenues
  SELECT [city], [TOTALSTREAMS],[TOTALREVENUE]
FROM #CityStreamingSummary
WHERE [TOTALSTREAMS] > 10000 AND [TOTALREVENUE] < 300000


--SUBQUERY
---AVERAGE STREAMS ACROSS CITIES
SELECT AVG([TOTALSTREAMS]) AS TOTALSTREAMS
  FROM #CityStreamingSummary

  --AVERAGE POPULATION
  SELECT AVG([city_population_mil]) AS TOTALPOPULATION
  FROM #CityStreamingSummary

  --Cities with above average population but below average streams
  SELECT 
    [city],
    [country],
    [subregion],
    [city_population_mil]                               AS [POPULATION_MIL],
    [TOTALSTREAMS],
    [TOTALREVENUE],
    [gdp_per_capita_usd],
    (SELECT AVG([TOTALSTREAMS]) FROM #CityStreamingSummary) 
    - [TOTALSTREAMS]                AS [STREAMS_BELOW_AVG],
    'Growth Opportunity'            AS [MARKET_STATUS]
FROM #CityStreamingSummary
WHERE 
    [city_population_mil] > (SELECT AVG([city_population_mil]) FROM #CityStreamingSummary)
AND [TOTALSTREAMS]        < (SELECT AVG([TOTALSTREAMS])        FROM #CityStreamingSummary)
ORDER BY [city_population_mil] DESC;