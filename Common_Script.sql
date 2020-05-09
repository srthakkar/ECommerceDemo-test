USE [ECommerceDemo]
GO

/****** Object:  UserDefinedFunction [dbo].[CSVtoTableWithIdentity]    Script Date: 09-May-20 4:37:45 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:        
-- Create date:  
-- Description:    Convert CSV to Table
-- =============================================
CREATE FUNCTION [dbo].[CSVtoTableWithIdentity]
(
    @LIST nvarchar(MAX),
    @Delimeter nvarchar(10)
)
RETURNS @RET1 TABLE (ReturnId INT, RESULT NVARCHAR(1000))
AS
BEGIN
    DECLARE @RET TABLE(ReturnId INT IDENTITY(1,1), RESULT NVARCHAR(1000))
    
    IF LTRIM(RTRIM(@LIST))='' RETURN  

    DECLARE @START BIGINT
    DECLARE @LASTSTART BIGINT
    SET @LASTSTART=0
    SET @START=CHARINDEX(@Delimeter,@LIST,0)

    IF @START=0
    INSERT INTO @RET VALUES(SUBSTRING(@LIST,0,LEN(@LIST)+1))

    WHILE(@START >0)
    BEGIN
        INSERT INTO @RET VALUES(SUBSTRING(@LIST,@LASTSTART,@START-@LASTSTART))
        SET @LASTSTART=@START+1
        SET @START=CHARINDEX(@Delimeter,@LIST,@START+1)
        IF(@START=0)
        INSERT INTO @RET VALUES(SUBSTRING(@LIST,@LASTSTART,LEN(@LIST)+1))
    END
    
    INSERT INTO @RET1 SELECT * FROM @RET
    RETURN 
END


GO

USE [ECommerceDemo]
GO

/****** Object:  StoredProcedure [dbo].[GetProductDetails]    Script Date: 09-May-20 4:36:57 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Sagar Thakkar
-- Create date: 09 May 2020
-- Description: This sp will return the product details and lookup
-- =============================================
CREATE PROCEDURE [dbo].[GetProductDetails]
	-- Add the parameters for the stored procedure here
	@ProductId BIGINT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT P.*,PC.CategoryName
	FROM Product P
	INNER JOIN ProductCategory PC ON PC.ProdCatId=P.ProdCatId
	WHERE P.ProductId=@ProductId;

	SELECT PA.*
	FROM ProductAttribute PA 
	INNER JOIN Product P ON P.ProductId=PA.ProductId
	WHERE PA.ProductId=@ProductId;

	SELECT * 
	FROM ProductCategory 

	SELECT * 
	FROM  ProductAttributeLookup PAL

	
END

GO


USE [ECommerceDemo]
GO

/****** Object:  StoredProcedure [dbo].[GetProductList]    Script Date: 09-May-20 4:37:17 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Sagar Thakkar
-- Create date: 09 May 2020
-- Description:	Return product list
-- =============================================
-- EXEC GetProductList @FromIndex = N'1', @ToIndex = N'1000', @SortType = N'DESC', @SortExpression = N'ProdName', @ProdName = N''
CREATE PROCEDURE [dbo].[GetProductList]
	@FromIndex INT,
	@ToIndex INT,
	@SortExpression VARCHAR(100),
	@SortType VARCHAR(10),	
	@ProdName VARCHAR(250)=NULL	
AS
BEGIN
	
	;WITH CTEProductList AS
	(         
		SELECT *,COUNT(T.ProductId) OVER() AS Count
		FROM
		(
			SELECT ROW_NUMBER() OVER 
						(ORDER BY							
							CASE
								WHEN @SortType = 'ASC' THEN CASE WHEN @SortExpression = 'ProdName' THEN P.ProdName END
							END ASC,
							CASE
								WHEN @SortType = 'DESC' THEN CASE WHEN @SortExpression = 'ProdName' THEN P.ProdName END
							END DESC
						) AS Row
			,P.ProductId,P.ProdName,P.ProdDescription,PC.CategoryName
			FROM Product P
			INNER JOIN ProductCategory PC ON PC.ProdCatId=P.ProdCatId
			WHERE 
			 (@ProdName IS NULL OR LEN(@ProdName)=0 OR P.ProdName like '%' + @ProdName +'%' )
			
		) AS T
	)
	SELECT * FROM CTEProductList WHERE ROW BETWEEN @FromIndex AND @ToIndex
END
GO


USE [ECommerceDemo]
GO

/****** Object:  StoredProcedure [dbo].[SaveProduct]    Script Date: 09-May-20 4:36:05 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Sagar Thakkar
-- Create date: 09 May 2020
-- Description:	This sp will create products 
-- =============================================
-- EXEC SaveProduct @IsEditMode = N'False', @ProductId = N'0', @ProdCatId = N'1', @ProdName= N'Audi', @ProdDescription= N'Nice car',@ProductAttributeList= N'1|Red,2|Audi'
-- EXEC SaveProduct @IsEditMode = N'True', @ProductId = N'1', @ProdCatId = N'1', @ProdName= N'Audi updated', @ProdDescription= N'fast car',@ProductAttributeList= N'1|Black,2|MHP'
-- EXEC SaveProduct @IsEditMode = N'True', @ProductId = N'1', @ProdCatId = N'1', @ProdName= N'Audi updated', @ProdDescription= N'fast car',@ProductAttributeList= N'1|Black,2|MHP,3|temp'
CREATE PROCEDURE [dbo].[SaveProduct]
	-- Add the parameters for the stored procedure here
	@IsEditMode BIT,
	@ProductId BIGINT,
	@ProdCatId INT,
	@ProdName VARCHAR(250),
	@ProdDescription VARCHAR(MAX),
	@ProductAttributeList VARCHAR(MAX)
	
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @TablePrimaryId BIGINT;
	DECLARE @TEMPTABLE TABLE (AttributeId INT,AttributeValue VARCHAR(250))

	BEGIN TRANSACTION trans			 
	BEGIN TRY
						INSERT INTO @TEMPTABLE
						SELECT 
						(SELECT Result FROM [dbo].[CSVtoTableWithIdentity](Result,'|') WHERE ReturnId = 1) AS AttributeId,
						(SELECT Result FROM [dbo].[CSVtoTableWithIdentity](Result,'|') WHERE ReturnId = 2) AS AttributeValue
						FROM [dbo].[CSVtoTableWithIdentity](@ProductAttributeList,',')

					IF(@IsEditMode=1)
					BEGIN
							DECLARE @IsProductCategoryChanged BIT = (SELECT 1 FROM Product WHERE ProductId=@ProductId AND ProdCatId <> @ProdCatId);

							-- update product
							UPDATE Product
							SET
								ProdCatId=@ProdCatId, 
								ProdName=@ProdName,
								ProdDescription=@ProdDescription								
							WHERE ProductId=@ProductId;

							SET @TablePrimaryId = @ProductId;				

							IF(@IsProductCategoryChanged=1)
							BEGIN
									-- Delete old product attributes 
									DELETE FROM ProductAttribute WHERE ProductId=@TablePrimaryId;

									-- Add new product attributes
									INSERT INTO ProductAttribute
									(ProductId,AttributeId,AttributeValue)
									SELECT @TablePrimaryId AS ProductId,T.AttributeId,T.AttributeValue 
									FROM @TEMPTABLE T

							END
							ELSE
							BEGIN
									-- Updated Attribute value
									UPDATE PA
									SET PA.AttributeValue=T.AttributeValue
									FROM ProductAttribute PA
									INNER JOIN @TEMPTABLE T ON T.AttributeId=PA.AttributeId
									WHERE PA.ProductId=@TablePrimaryId;

									-- IF new Attribute added in lookup in future
									IF EXISTS 
									(
										SELECT PL.* 
										FROM ProductAttributeLookup PL 
										INNER JOIN Product P ON P.ProdCatId=PL.ProdCatId
										WHERE PL.AttributeId NOT IN (SELECT AttributeId FROM ProductAttribute WHERE ProductId=@TablePrimaryId)
									)
									BEGIN
											-- Add product attribute
											INSERT INTO ProductAttribute
											(ProductId,AttributeId,AttributeValue)
											SELECT P.ProductId,PL.AttributeId,'' 
											FROM ProductAttributeLookup PL 
											INNER JOIN Product P ON P.ProdCatId=PL.ProdCatId
											WHERE PL.AttributeId NOT IN (SELECT AttributeId FROM ProductAttribute WHERE ProductId=@TablePrimaryId)

									END


							END
					END
					ELSE
					BEGIN
							-- Add product
							INSERT INTO Product
							(ProdCatId,ProdName,ProdDescription)
							VALUES
							(@ProdCatId,@ProdName,@ProdDescription);

							SET @TablePrimaryId = SCOPE_IDENTITY();		

							-- Add product attribute
							INSERT INTO ProductAttribute
							(ProductId,AttributeId,AttributeValue)
							SELECT @TablePrimaryId AS ProductId,T.AttributeId,T.AttributeValue 
							FROM @TEMPTABLE T
						
					END

					SELECT 1 AS TransactionResultId,@TablePrimaryId AS TablePrimaryId;					
		
			
			IF @@TRANCOUNT > 0
						BEGIN COMMIT TRANSACTION trans
			END
	END TRY
	
	BEGIN CATCH
				SELECT -1 AS TransactionResultId,ERROR_MESSAGE() AS ErrorMessage;				
				IF @@TRANCOUNT > 0
				BEGIN ROLLBACK TRANSACTION trans 
	END
	END CATCH 

END
GO





