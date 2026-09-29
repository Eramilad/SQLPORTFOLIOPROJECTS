SELECT TOP (1000) [make]
      ,[fuel_type]
      ,[num_of_doors]
      ,[body_style]
      ,[drive_wheels]
      ,[engine_location]
      ,[wheel_base]
      ,[length]
      ,[width]
      ,[height]
      ,[curb_weight]
      ,[engine_type]
      ,[num_of_cylinders]
      ,[engine_size]
      ,[fuel_system]
      ,[compression_ratio]
      ,[horsepower]
      ,[city_mpg]
      ,[highway_mpg]
      ,[price]
  FROM [Google data analysis].[dbo].[automobile data]



  SELECT *
   FROM [Google data analysis].[dbo].[automobile data]
   ORDER BY [height]


   SELECT *
   FROM [Google data analysis].[dbo].[automobile data]
   ORDER BY [height] DESC

   SELECT *
   FROM [Google data analysis].[dbo].[automobile data]
   WHERE make = 'dodge'
   ORDER BY [height] DESC


   SELECT *
   FROM [Google data analysis].[dbo].[automobile data]
   WHERE make = 'dodge'
   AND height > 50.2
   AND length > 171.0
   ORDER BY [height] DESC
