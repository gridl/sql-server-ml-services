USE ML
GO

SELECT [id]
      ,[cycle]
      ,[RUL]
      ,[label1]
FROM [PredictiveMaintenance].[train_Labels]
WHERE [RUL] BETWEEN 20 AND 35;
GO

SELECT [label1], COUNT(*) AS nr
FROM [PredictiveMaintenance].[train_Labels]
GROUP BY [label1]

SELECT [label1], COUNT(*) AS nr
FROM [PredictiveMaintenance].[Test_Features]
GROUP BY [label1];
GO

--TRUNCATE TABLE [PredictiveMaintenance].[Binary_metrics]

WITH ranking AS 
	(SELECT *, ROW_NUMBER() OVER (ORDER BY [F-Score] DESC) as Rn
	FROM [PredictiveMaintenance].[Binary_metrics])
SELECT [Name], [Variables], [F-Score], Accuracy, Rn
FROM ranking
WHERE Rn <=5 OR Rn >25
ORDER BY [F-Score] DESC;

SELECT [label1], 100. * count(*)/13096 AS pct
FROM [PredictiveMaintenance].[test_Labels]
GROUP BY [label1];

SELECT [label1], 1. * count(*) AS pct
FROM [PredictiveMaintenance].[Test_Features] 
GROUP BY [label1];
 
GO

EXEC sp_helptext'[PredictiveMaintenance].[TrainBinaryClassificationModel]'
GO

DELETE FROM [PredictiveMaintenance].[Models]	
WHERE model_name IN ('rxFastLinear binary classification','rxNeuralNet binary classification','rxEnsemble binary classification');
GO

DECLARE @model VARBINARY(MAX);
EXEC [PredictiveMaintenance].[TrainBinaryClassificationModel] 'rxFastTrees','[PredictiveMaintenance].[train_Features_Normalized]', 20,
	 @model OUTPUT;
INSERT INTO [PredictiveMaintenance].[Models] (model_name, model) 
VALUES('rxFastTrees binary classification', @model);
GO

DECLARE @model VARBINARY(MAX);
EXEC [PredictiveMaintenance].[TrainBinaryClassificationModel] 'rxNeuralNet','[PredictiveMaintenance].[train_Features_Normalized]', 20,
	 @model OUTPUT;
INSERT INTO [PredictiveMaintenance].[Models] (model_name, model) 
VALUES('rxNeuralNet binary classification', @model);
GO

DECLARE @model VARBINARY(MAX);
EXEC [PredictiveMaintenance].[TrainBinaryClassificationModel] 'rxEnsemble','[PredictiveMaintenance].[Train_Features]', 20,
	 @model OUTPUT;
INSERT INTO [PredictiveMaintenance].[Models] (model_name, model) 
VALUES('rxEnsemble binary classification', @model);
GO

DECLARE @model varbinary(max) = ( SELECT model FROM [PredictiveMaintenance].[Models] WHERE model_name = 'rxFastTrees binary classification');
EXEC sp_rxPredict
	@model = @model,
	@inputData = N'SELECT CAST(label1 as varchar(100)) AS label1, s11 , s4 , s12 , s7 , s15 , s21 , s20 , s17 , s2 , s3 , 
    s8 , s13 , s9 , s6 , a9 , a6 , sd12 , sd6 , sd9 , sd7
	FROM [PredictiveMaintenance].[test_Features_Normalized]';
GO

DECLARE @model varbinary(max) = ( SELECT model FROM [PredictiveMaintenance].[Models] 
	WHERE model_name = 'rxEnsemble binary classification');
EXEC sp_rxPredict
	@model = @model,
	@inputData = N'SELECT CAST(label1 as varchar(100)) AS label1, s11 , s4 , s12 , s7 , s15 , s21 , s20 , s17 , s2 , s3 , 
    s8 , s13 , s9 , s6 , a9 , a6 , sd12 , sd6 , sd9 , sd7
	FROM [PredictiveMaintenance].[Train_Features]';
GO

DECLARE @Predictions TABLE (
	[PredictedLabel] VARCHAR(256), 
	[Score.1] DECIMAL (5,3), 
	[Probability.1] DECIMAL (5,3));
DECLARE @model varbinary(max) = ( SELECT model FROM [PredictiveMaintenance].[Models] WHERE model_name = 'rxNeuralNet binary classification');
INSERT INTO @Predictions
EXEC sp_rxPredict
	@model = @model,
	@inputData = N'SELECT CAST(label1 as varchar(100)) AS label1, s11 , s4 , s12 , s7 , s15,
	s21 , s20 , s17 , s2 , s3 , s8 , s13 , s9 , s6 , a9 , a6 , sd12 , sd6 , sd9 , sd7
	FROM [PredictiveMaintenance].[test_Features_Normalized]';
SELECT CASE 
	WHEN [Probability.1]>0.4 THEN 1
	ELSE 0 
	END AS [PredictedLabel],
	[Probability.1]
FROM @Predictions;
GO