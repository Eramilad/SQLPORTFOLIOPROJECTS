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


  SELECT country
   FROM [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
   WHERE LEN(COUNTRY) > 2

    SELECT Distinct country
  FROM [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
  WHERE SUBSTRING(country,1,2) = 'CÃ'


  SELECT Distinct city
   FROM [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
  WHERE SUBSTRING(city,1,2) = 'Ib'

   SELECT Distinct stream_id
  FROM [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
   WHERE Trim(city) = 'Ibadan'


   SELECT 
     MAX(city_population_mil) as max_city_population_mil,
     MIN(city_population_mil) as min_city_population_mil
   FROM
      [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
  

  SELECT 
    MAX(internet_penetration_pct) AS max_internet_penetration_pct,
    MIN(internet_penetration_pct) AS min_internet_penetration_pct
  FROM 
    [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]


    SELECT
          *
    FROM 
         [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
    WHERE 
         gdp_per_capita_usd IS NULL;


     SELECT 
           *
     FROM 
          [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
     WHERE
           internet_penetration_pct IS NULL;




    UPDATE 
          [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
    SET 
        city_population_mil = 5.6
    WHERE 
        city = 'ibadan'



SELECT 
       DISTINCT city,
       LEN (city) as city_length
FROM 
       [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]


       UPDATE 
             [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
        SET 
            city = TRIM(city)


    SELECT 
          CAST(city_population_mil  AS FLOAT)
   FROM
          [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
   ORDER BY
           CAST(city_population_mil AS FLOAT) DESC



  SELECT 
          CAST(city_population_mil  AS FLOAT)
   FROM
          [Top Music Sreaming Cities Africa - Portfolio Project].[dbo].[City Info - Top Music Streaming Cities in Africa. - Sheet1]
   ORDER BY
           CAST(city_population_mil AS FLOAT) DESC

