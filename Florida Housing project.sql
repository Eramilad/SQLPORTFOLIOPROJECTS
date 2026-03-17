SELECT TOP (1000) [UniqueID ]
      ,[ParcelID]
      ,[LandUse]
      ,[PropertyAddress]
      ,[SaleDate]
      ,[SalePrice]
      ,[LegalReference]
      ,[SoldAsVacant]
      ,[OwnerName]
      ,[OwnerAddress]
      ,[Acreage]
      ,[TaxDistrict]
      ,[LandValue]
      ,[BuildingValue]
      ,[TotalValue]
      ,[YearBuilt]
      ,[Bedrooms]
      ,[FullBath]
      ,[HalfBath]
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]


  --Cleaning Data in SQL QUERIES
  SELECT *
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]

  --Standerdize Date Format
SELECT SALEDATECONVERTED, CONVERT(Date,SaleDate)
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]

  Update [Nashville Housing]
  SET SaleDate = CONVERT(Date,SaleDate)

  ALTER TABLE [Nashville Housing]
  ADD SALEDATECONVERTED Date

  Update [Nashville Housing]
  SET SALEDATECONVERTED = CONVERT(Date,SaleDate)

  --Populate Propert Address Data
  SELECT [PropertyAddress]
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  Where [PropertyAddress] Is Null

  SELECT a.ParcelID, b.ParcelID,  a.[PropertyAddress], b.[PropertyAddress], ISNULL(a.[PropertyAddress],b.[PropertyAddress])
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing] a
  Join [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing] b
  On a.ParcelID = b.ParcelID
  AND a.[UniqueID ] <> b.[UniqueID ]
  WHERE a.PropertyAddress is null

  UPDATE a
  SET PropertyAddress = ISNULL(a.[PropertyAddress],b.[PropertyAddress])
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing] a
  Join [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing] b
  On a.ParcelID = b.ParcelID
  AND a.[UniqueID ] <> b.[UniqueID ]
  WHERE a.PropertyAddress is null

  --Breaking Out address into individual Column(Address, City, State)
  SELECT [PropertyAddress]
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  --Where [PropertyAddress] Is Null
  --Order by ParcelID

  SELECT
  SUBSTRING([PropertyAddress], 1, CHARINDEX(',', PropertyAddress) -1) AS ADDRESS
  ,SUBSTRING([PropertyAddress], 1, CHARINDEX(',', PropertyAddress) +1), LEN(PropertyAddress) as ADDRESS

  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]

  

  ALTER TABLE [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  ADD PropertySplitAddress Nvarchar(255);

  Update [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  SET PropertySplitAddress = SUBSTRING([PropertyAddress], 1, CHARINDEX(',', PropertyAddress) -1)

  ALTER TABLE [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  ADD PropertySplitCity Nvarchar(255)

  Update [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  SET PropertySplitCity  = SUBSTRING([PropertyAddress], CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress))


  SELECT *
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]

  SELECT OwnerAddress
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]

  SELECT 
  PARSENAME(REPLACE(OWNERADDRESS, '.', '.'),3),
  PARSENAME(REPLACE(OWNERADDRESS, '.', '.'),2),
  PARSENAME(REPLACE(OWNERADDRESS, '.', '.'),1)
  FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]




  ALTER TABLE [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  ADD OwnerSplitAddress Nvarchar(255);

  Update [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  SET OwnerSplitAddress = PARSENAME(REPLACE(OWNERADDRESS, '.', '.'),3)

  ALTER TABLE [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  ADD OwnerSplitCity Nvarchar(255)

  Update [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  SET OwnerSplitCity  = PARSENAME(REPLACE(OWNERADDRESS, '.', '.'),2)

  ALTER TABLE [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  ADD OwnerSplitState Nvarchar(255)

  Update [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  SET OwnerSplitState  = PARSENAME(REPLACE(OWNERADDRESS, '.', '.'),1


  --Change Y and N to Yes and No In 'Sold as Vacant' Field

  Select Distinct(SoldAsVacant), Count(SoldAsVacant)
  From [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  Group by SoldAsVacant
  Order by SoldAsVacant


  Select SoldAsVacant
  , CASE When SoldAsVacant = 'Y' Then 'Yes'
         When SoldAsVacant = 'N' Then 'No'
         ELSE SoldAsVacant
         END
  From [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]


  UPDATE [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
  SET SoldAsVacant = CASE When SoldAsVacant = 'Y' Then 'Yes'
         When SoldAsVacant = 'N' Then 'No'
         ELSE SoldAsVacant
         END



--REMOVE Duplicates


With RowNumCTE AS(
Select *,
  ROW_NUMBER() OVER(
  PARTITION BY ParcelID,
               PropertyAddress,
               SalePrice,
               SaleDate,
               LegalReference
               ORDER BY
                UniqueID
                ) row_num
FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
)
SELECT *
From RowNumCTE
where row_num > 1



--DELETE UNUSED COLUMN
SELECT *
FROM [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]

ALTER TABLE [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress

ALTER TABLE [FLORIDA HOUSING PORTFOLIO PROJECT].[dbo].[Nashville Housing]
DROP COLUMN SaleDate