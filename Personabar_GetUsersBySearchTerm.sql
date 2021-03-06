IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'{databaseOwner}[{objectQualifier}Users]') AND name = N'IX_{objectQualifier}Users_FirstName')
	DROP INDEX [IX_{objectQualifier}Users_FirstName] ON {databaseOwner}[{objectQualifier}Users]
GO

CREATE NONCLUSTERED INDEX [IX_{objectQualifier}Users_FirstName] ON {databaseOwner}[{objectQualifier}Users]
	([FirstName] ASC, [IsSuperUser] ASC, [IsDeleted] ASC)
	INCLUDE ([UserID]) 
	WHERE ([FirstName] IS NOT NULL AND [FirstName] <> N'')
GO


IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'{databaseOwner}[{objectQualifier}Users]') AND name = N'IX_{objectQualifier}Users_LastName')
	DROP INDEX [IX_{objectQualifier}Users_LastName] ON {databaseOwner}[{objectQualifier}Users]
GO

CREATE NONCLUSTERED INDEX [IX_{objectQualifier}Users_LastName] ON {databaseOwner}[{objectQualifier}Users]
	([LastName] ASC, [IsSuperUser] ASC, [IsDeleted] ASC)
	INCLUDE ([UserID]) 
	WHERE ([LastName] IS NOT NULL AND [LastName] <> N'')
GO 


IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'{databaseOwner}[{objectQualifier}Users]') AND name = N'IX_{objectQualifier}Users_DisplayName')
	DROP INDEX [IX_{objectQualifier}Users_DisplayName] ON {databaseOwner}[{objectQualifier}Users]
GO

CREATE NONCLUSTERED INDEX [IX_{objectQualifier}Users_DisplayName] ON {databaseOwner}[{objectQualifier}Users]
    ([DisplayName] ASC, [IsSuperUser] ASC, [IsDeleted] ASC)
     INCLUDE ([UserId])
GO


IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'{databaseOwner}[{objectQualifier}Users]') AND name = N'IX_{objectQualifier}Users_IsSuperuser')
	DROP INDEX [IX_{objectQualifier}Users_IsSuperuser] ON {databaseOwner}[{objectQualifier}Users]
GO

CREATE UNIQUE NONCLUSTERED INDEX [IX_{objectQualifier}Users_IsSuperuser] ON {databaseOwner}[{objectQualifier}Users]
	([IsSuperUser] DESC, [UserName] ASC)
	INCLUDE  ([UserID], [DisplayName], [FirstName], [LastName], [Email], [LastModifiedOnDate], [isDeleted]) 
	WHERE ([IsSuperUser] = (1))
GO


IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'{databaseOwner}[{objectQualifier}UserPortals]') AND name = N'IX_{objectQualifier}UserPortals_PortalId_IsDeleted')
    DROP INDEX [IX_{objectQualifier}UserPortals_PortalId_IsDeleted] ON {databaseOwner}[{objectQualifier}UserPortals]
GO

CREATE UNIQUE NONCLUSTERED INDEX [IX_{objectQualifier}UserPortals_PortalId_IsDeleted] ON {databaseOwner}[{objectQualifier}UserPortals]
    ([PortalId] ASC, [isDeleted] ASC, [Authorised] DESC, [UserID])
GO


IF EXISTS (select * from Sys.Views where object_id = object_id(N'{databaseOwner}[{objectQualifier}vw_ProfileDataTypes]'))
    DROP VIEW {databaseOwner}[{objectQualifier}vw_ProfileDataTypes]
GO

CREATE VIEW {databaseOwner}[{objectQualifier}vw_ProfileDataTypes]
AS
    SELECT [EntryID] AS DataTypeID,
           [Value]   AS TypeName,
           [Text]    AS ControlName
      FROM {databaseOwner}[{objectQualifier}Lists]
     WHERE ListName = N'DataType';
GO


IF EXISTS (select * from Sys.Views where object_id = object_id(N'{databaseOwner}[{objectQualifier}vw_ProfileBase]'))
    DROP VIEW {databaseOwner}[{objectQualifier}vw_ProfileBase]
GO

-- View vw_ProfileBase
CREATE VIEW {databaseOwner}[{objectQualifier}vw_ProfileBase]

AS
    SELECT
        UP.UserID,
        PD.PortalID,
        PD.PropertyName,
        UP.PropertyValue,
        UP.PropertyText,
        UP.PropertyKey,
        CASE WHEN PD.visible = 0 THEN 1
             ELSE UP.Visibility
        END Visibility,
        CASE WHEN PD.visible = 1 and UP.Visibility = 3
             THEN UP.ExtendedVisibility
             ELSE ''
        END ExtendedVisibility,
        PD.Deleted,
        PD.DataType,
        DT.TypeName,
        PD.PropertyDefinitionID,
        CASE WHEN UP.LastUpdatedDate > PD.LastModifiedOnDate
             THEN UP.LastUpdatedDate
             ELSE PD.LastModifiedOnDate
        END LastUpdatedDate
    FROM {databaseOwner}[{objectQualifier}UserProfile]               AS UP
    JOIN {databaseOwner}[{objectQualifier}ProfilePropertyDefinition] AS PD ON PD.PropertyDefinitionID = UP.PropertyDefinitionID
    JOIN {databaseOwner}[{objectQualifier}vw_ProfileDataTypes]       AS DT ON PD.DataType = DT.DataTypeID;
GO


-- DNN-4361: extended to include DataTypeName and support List dataType lookup, using DNN-4362
IF EXISTS (select * from Sys.Views where object_id = object_id(N'{databaseOwner}[{objectQualifier}vw_Profile]'))
    DROP VIEW {databaseOwner}[{objectQualifier}vw_Profile]
GO

CREATE VIEW {databaseOwner}[{objectQualifier}vw_Profile]

AS
    SELECT
        P.UserID,
        P.PortalID,
        P.PropertyName,
        CASE
         WHEN P.TypeName = N'List'                  THEN IsNull(L.[Text], P.PropertyValue)
         WHEN P.TypeName IN (N'Region', N'Country') THEN IsNull(M.[Text], M.[Value])
         WHEN IsNull(P.PropertyText, N'') = N''     THEN P.PropertyValue
         ELSE P.PropertyText
        END AS PropertyValue,
        P.Visibility,
        P.ExtendedVisibility,
        P.Deleted,
        P.DataType,
        P.TypeName,
        P.LastUpdatedDate,
        P.PropertyDefinitionID
    FROM      {databaseOwner}[{objectQualifier}vw_ProfileBase] AS P
    LEFT JOIN {databaseOwner}[{objectQualifier}Lists]          AS M ON P.PropertyKey   = M.EntryID
    LEFT JOIN {databaseOwner}[{objectQualifier}Lists]          AS L ON P.PropertyName  = L.ListName AND P.PropertyValue = L.Value;
GO
    

IF EXISTS (SELECT * FROM sys.procedures WHERE object_id = object_id(N'{databaseOwner}[{objectQualifier}Personabar_GetUsersBySearchTerm]'))
	DROP PROCEDURE {databaseOwner}[{objectQualifier}Personabar_GetUsersBySearchTerm]
GO

CREATE PROCEDURE {databaseOwner}[{objectQualifier}Personabar_GetUsersBySearchTerm]
	@PortalId      Int,           --  Null|-1: any Site
	@SortColumn    nVarChar(32),  --  Field Name, supported values see below. Null|'': sort by search priority
	@SortAscending Bit =  1,      --  Sort Direction
	@PageIndex     Int =  0,
	@PageSize      Int = 10,
	@SearchTerm    nVarChar(99),  --  Null|'': all items, append "%" to perform a left search
	@authorized    Bit,           --  Null: all, 0: unauthorized only, 1: authorized only
	@isDeleted     Bit,           --  Null: all, 0: undeleted    only, 1: deleted    only
	@Superusers    Bit            --  Null|0: portal users only, 1: superusers only
AS
BEGIN
	IF @SearchTerm = N''   SET @SearchTerm = Null; -- Normalize parameter
	IF @SortColumn = N''   SET @SortColumn = N'Priority';
	IF @SortColumn Is Null SET @SortColumn = N'Priority';
	
	IF (@Superusers = 1)
	BEGIN
	  IF (@SearchTerm Is Null) -- search superusers
	  BEGIN
		SELECT U.UserID, U.Username, U.DisplayName, U.Email, U.CreatedOnDate, U.IsDeleted, Authorised, IsSuperUser, TotalCount
		FROM (SELECT UserID, Username, DisplayName, Email, CreatedOnDate, IsDeleted, 1 AS Authorised, IsSuperUser, Count(*) OVER () AS TotalCount,
				 ROW_NUMBER() OVER (ORDER BY CASE WHEN @SortColumn = N'Joined'      AND @SortAscending = 1 THEN UserID               END ASC, 
											 CASE WHEN @SortColumn = N'Joined'      AND @SortAscending = 0 THEN UserID               END DESC,
											 CASE WHEN @SortColumn = N'Email'       AND @SortAscending = 1 THEN Email                END ASC, 
											 CASE WHEN @SortColumn = N'Email'       AND @SortAscending = 0 THEN Email                END DESC,
											 CASE WHEN @SortColumn = N'DisplayName' AND @SortAscending = 1 THEN DisplayName          END ASC, 
											 CASE WHEN @SortColumn = N'DisplayName' AND @SortAscending = 0 THEN DisplayName          END DESC,
											 CASE WHEN @SortColumn = N'UserName'    AND @SortAscending = 1 THEN UserName			 END ASC,
											 CASE WHEN @SortColumn = N'UserName'    AND @SortAscending = 0 THEN UserName			 END DESC,
											 CASE WHEN @SortColumn = N'Priority'    AND @SortAscending = 1 THEN UserName			 END ASC, -- Priority not supported
											 CASE WHEN @SortColumn = N'Priority'    AND @SortAscending = 0 THEN UserName			 END DESC,-- Priority not supported
											 CASE WHEN @SortColumn = N'Modified'    AND @SortAscending = 1 THEN LastModifiedOnDate   END ASC, 
											 CASE WHEN @SortColumn = N'Modified'    AND @SortAscending = 0 THEN LastModifiedOnDate   END DESC) AS RowNumber 
		   FROM  {databaseOwner}[{objectQualifier}Users]
		   WHERE (IsSuperUser = 1)
		     AND (@isDeleted  Is Null OR IsDeleted = @isDeleted)) U
		WHERE RowNumber BETWEEN (@PageIndex * @PageSize + 1) AND ((@PageIndex + 1) * @PageSize)
		ORDER BY RowNumber
		OPTION (RECOMPILE);
	  END
	  ELSE -- search superusers using term
	  BEGIN
		SELECT UserID, Username, DisplayName, Email, CreatedOnDate, IsDeleted, 1 AS Authorised, IsSuperUser, TotalCount
		 FROM  (SELECT UserID, 
		               Username, 
					   DisplayName,
					   Email,
					   CreatedOnDate,
					   IsDeleted,
					   IsSuperUser,
		               Sum(1) N, 
					   Count(*) OVER ()   AS TotalCount,
		               ROW_NUMBER() OVER (ORDER BY CASE WHEN @SortColumn = N'Joined'      AND @SortAscending = 1 THEN UserID               END ASC, 
												   CASE WHEN @SortColumn = N'Joined'      AND @SortAscending = 0 THEN UserID               END DESC,
												   CASE WHEN @SortColumn = N'Email'       AND @SortAscending = 1 THEN Email                END ASC, 
												   CASE WHEN @SortColumn = N'Email'       AND @SortAscending = 0 THEN Email                END DESC,
												   CASE WHEN @SortColumn = N'DisplayName' AND @SortAscending = 1 THEN DisplayName          END ASC, 
												   CASE WHEN @SortColumn = N'DisplayName' AND @SortAscending = 0 THEN DisplayName          END DESC,
												   CASE WHEN @SortColumn = N'UserName'    AND @SortAscending = 1 THEN UserName			   END ASC,
												   CASE WHEN @SortColumn = N'UserName'    AND @SortAscending = 0 THEN UserName			   END DESC,
												   CASE WHEN @SortColumn = N'Priority'    AND @SortAscending = 1 THEN Sum(1)			   END ASC,
												   CASE WHEN @SortColumn = N'Priority'    AND @SortAscending = 0 THEN Sum(1)			   END DESC,
												   CASE WHEN @SortColumn = N'Modified'    AND @SortAscending = 1 THEN LastModifiedOnDate   END ASC, 
												   CASE WHEN @SortColumn = N'Modified'    AND @SortAscending = 0 THEN LastModifiedOnDate   END DESC) AS RowNumber 
				  FROM (SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsDeleted, IsSuperUser
						FROM  {databaseOwner}[{objectQualifier}Users] 
						WHERE (UserName    Like @searchTerm)
						  AND (IsSuperUser = 1)
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted) 
					   UNION SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsDeleted, IsSuperUser
						FROM  {databaseOwner}[{objectQualifier}Users]
						WHERE (DisplayName Like @searchTerm)
						  AND (IsSuperUser = 1)
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted) 
					   UNION SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsDeleted, IsSuperUser
						FROM  {databaseOwner}[{objectQualifier}Users]
						WHERE (Email       Like @searchTerm)
						  AND (IsSuperUser = 1)
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted) 
					   UNION SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsDeleted, IsSuperUser
						FROM  {databaseOwner}[{objectQualifier}Users]
						WHERE (FirstName   Like @searchTerm)
						  AND FirstName Is Not Null AND FirstName != N'' 
						  AND (IsSuperUser = 1)
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted) 
					   UNION SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsDeleted, IsSuperUser
						FROM  {databaseOwner}[{objectQualifier}Users]
						WHERE (LastName    Like @searchTerm)
						  AND LastName  Is Not Null AND LastName  != N'' 
						  AND (IsSuperUser = 1)
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted)
					   UNION SELECT U.UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsDeleted, IsSuperuser 
						FROM  {databaseOwner}[{objectQualifier}Users] U
						JOIN  {databaseOwner}[{objectQualifier}vw_Profile] F ON U.UserID = F.UserID
						WHERE (F.PropertyValue Like @searchTerm) AND (F.PortalID = @PortalId or IsNull(@PortalId, -1) = -1)
						  AND F.PropertyValue  Is Not Null AND F.PropertyValue  != N'' 
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted)) S 
					 GROUP BY UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsDeleted, IsSuperUser) AS Sel
		WHERE Sel.RowNumber BETWEEN (@PageIndex * @PageSize + 1) AND ((@PageIndex + 1) * @PageSize)
		ORDER BY Sel.RowNumber
		OPTION (RECOMPILE);
	  END
	END
	ELSE IF (@SearchTerm Is Null)
	BEGIN -- display all portal users:
			DECLARE @TotalCount Int;
			SELECT @TotalCount = Count(1) 
			 FROM  {databaseOwner}[{objectQualifier}Users]       U
			 JOIN  {databaseOwner}[{objectQualifier}UserPortals] P ON U.UserID = P.UserID
			 WHERE P.PortalID = @PortalID
			   AND (@Superusers Is Null OR IsSuperUser = 0)
			   AND (@isDeleted  Is Null OR P.IsDeleted  = @isDeleted )
			   AND (@authorized Is Null OR P.Authorised = @authorized);
			   
			SELECT UserID, Username, DisplayName, Email, CreatedOnDate, IsDeleted, Authorised, IsSuperUser, @TotalCount AS TotalCount
			FROM
		     (SELECT U.UserID, U.Username, U.DisplayName, U.Email, U.CreatedOnDate, P.IsDeleted, P.Authorised, U.IsSuperUser,
			         ROW_NUMBER() OVER (ORDER BY CASE WHEN @SortColumn = N'Joined'      AND @SortAscending = 1 THEN U.UserID             END ASC, 
												 CASE WHEN @SortColumn = N'Joined'      AND @SortAscending = 0 THEN U.UserID             END DESC,
												 CASE WHEN @SortColumn = N'Email'       AND @SortAscending = 1 THEN Email                END ASC, 
												 CASE WHEN @SortColumn = N'Email'       AND @SortAscending = 0 THEN Email                END DESC,
												 CASE WHEN @SortColumn = N'DisplayName' AND @SortAscending = 1 THEN DisplayName          END ASC, 
												 CASE WHEN @SortColumn = N'DisplayName' AND @SortAscending = 0 THEN DisplayName          END DESC,
												 CASE WHEN @SortColumn = N'UserName'    AND @SortAscending = 1 THEN UserName			 END ASC,
												 CASE WHEN @SortColumn = N'UserName'    AND @SortAscending = 0 THEN UserName			 END DESC,
												 CASE WHEN @SortColumn = N'Priority'    AND @SortAscending = 1 THEN UserName			 END ASC, -- Priority not supported
												 CASE WHEN @SortColumn = N'Priority'    AND @SortAscending = 0 THEN UserName			 END DESC,-- Priority not supported
												 CASE WHEN @SortColumn = N'Modified'    AND @SortAscending = 1 THEN U.LastModifiedOnDate END ASC, 
												 CASE WHEN @SortColumn = N'Modified'    AND @SortAscending = 0 THEN U.LastModifiedOnDate END DESC) AS RowNumber 
			   FROM  {databaseOwner}[{objectQualifier}Users]       U
			   JOIN  {databaseOwner}[{objectQualifier}UserPortals] P ON U.UserID = P.UserID
			   WHERE P.PortalID = @PortalID
			     AND (@Superusers Is Null OR U.IsSuperuser = 0)
			     AND (@isDeleted  Is Null OR P.IsDeleted  = @isDeleted)
			     AND (@authorized Is Null OR P.Authorised = @authorized)) Sel
			 WHERE Sel.RowNumber BETWEEN (@PageIndex * @PageSize + 1) AND ((@PageIndex + 1) * @PageSize)
			 ORDER BY Sel.RowNumber
			 OPTION (RECOMPILE);
	END
	ELSE -- search portal users:
	BEGIN
		SELECT UserID, Username, DisplayName, Email, CreatedOnDate, IsDeleted, Authorised, IsSuperUser, TotalCount
		FROM  ( SELECT S.UserID, 
		               Username, 
					   DisplayName,
					   Email,
					   CreatedOnDate,
					   IsDeleted,
					   Authorised,
					   IsSuperUser,
		               Sum(1) N, 
					   Count(*) OVER ()   AS TotalCount,
		               ROW_NUMBER() OVER (ORDER BY CASE WHEN @SortColumn = N'Joined'      AND @SortAscending = 1 THEN S.UserID             END ASC, 
												   CASE WHEN @SortColumn = N'Joined'      AND @SortAscending = 0 THEN S.UserID             END DESC,
												   CASE WHEN @SortColumn = N'Email'       AND @SortAscending = 1 THEN Email                END ASC, 
												   CASE WHEN @SortColumn = N'Email'       AND @SortAscending = 0 THEN Email                END DESC,
												   CASE WHEN @SortColumn = N'DisplayName' AND @SortAscending = 1 THEN DisplayName          END ASC, 
												   CASE WHEN @SortColumn = N'DisplayName' AND @SortAscending = 0 THEN DisplayName          END DESC,
												   CASE WHEN @SortColumn = N'UserName'    AND @SortAscending = 1 THEN UserName			   END ASC,
												   CASE WHEN @SortColumn = N'UserName'    AND @SortAscending = 0 THEN UserName			   END DESC,
												   CASE WHEN @SortColumn = N'Priority'    AND @SortAscending = 1 THEN Sum(1)			   END ASC,
												   CASE WHEN @SortColumn = N'Priority'    AND @SortAscending = 0 THEN Sum(1)			   END DESC,
												   CASE WHEN @SortColumn = N'Modified'    AND @SortAscending = 1 THEN LastModifiedOnDate   END ASC, 
												   CASE WHEN @SortColumn = N'Modified'    AND @SortAscending = 0 THEN LastModifiedOnDate   END DESC) AS RowNumber 
				  FROM (SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsSuperuser 
						FROM  {databaseOwner}[{objectQualifier}Users] 
						WHERE (UserName    Like @searchTerm)
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted) 
					   UNION SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsSuperuser 
						FROM  {databaseOwner}[{objectQualifier}Users]
						WHERE (DisplayName Like @searchTerm)
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted) 
					   UNION SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsSuperuser 
						FROM  {databaseOwner}[{objectQualifier}Users]
						WHERE (Email       Like @searchTerm)
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted) 
					   UNION SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsSuperuser 
						FROM  {databaseOwner}[{objectQualifier}Users]
						WHERE (FirstName   Like @searchTerm)
						  AND FirstName Is Not Null AND FirstName != N'' 
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted) 
					   UNION SELECT UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsSuperuser 
						FROM  {databaseOwner}[{objectQualifier}Users]
						WHERE (LastName    Like @searchTerm)
						  AND LastName  Is Not Null AND LastName  != N'' 
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted)
					   UNION SELECT U.UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsSuperuser 
						FROM  {databaseOwner}[{objectQualifier}Users] U
						JOIN  {databaseOwner}[{objectQualifier}vw_Profile] F ON U.UserID = F.UserID
						WHERE (F.PropertyValue Like @searchTerm) AND (F.PortalID = @PortalId or IsNull(@PortalId, -1) = -1)
						  AND F.PropertyValue  Is Not Null AND F.PropertyValue  != N'' 
						  AND (@isDeleted  Is Null OR IsDeleted = @isDeleted)) S
                   JOIN	 {databaseOwner}[{objectQualifier}UserPortals] P ON S.UserID = P.UserID		
                   WHERE P.PortalID = @PortalID
					 AND (@Superusers Is Null OR S.IsSuperuser = 0)
					 AND (@isDeleted  Is Null OR P.IsDeleted  = @isDeleted)
			         AND (@authorized Is Null OR P.Authorised = @authorized)
				   GROUP BY S.UserID, Username, DisplayName, Email, CreatedOnDate, LastModifiedOnDate, IsDeleted, IsSuperuser, Authorised) AS Sel
		WHERE Sel.RowNumber BETWEEN (@PageIndex * @PageSize + 1) AND ((@PageIndex + 1) * @PageSize)
		ORDER BY Sel.RowNumber
		OPTION (RECOMPILE);
	END
END; --Procedure
GO