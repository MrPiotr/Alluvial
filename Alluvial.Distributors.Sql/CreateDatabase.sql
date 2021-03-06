/****** Object:  Database [AlluvialSqlDistributor]    Script Date: 7/5/2015 10:12:00 AM ******/

ALTER DATABASE [AlluvialSqlDistributor] SET COMPATIBILITY_LEVEL = 110
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
BEGIN
EXEC [AlluvialSqlDistributor].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [AlluvialSqlDistributor] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET ARITHABORT OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET  DISABLE_BROKER 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET  MULTI_USER 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [AlluvialSqlDistributor] SET DB_CHAINING OFF 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [AlluvialSqlDistributor] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO

USE [AlluvialSqlDistributor]

GO

IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Alluvial')) 
BEGIN
    EXEC ('CREATE SCHEMA [Alluvial]')
END
GO

IF object_id('[Alluvial].[Tokens]') IS NULL
BEGIN
	CREATE SEQUENCE [Alluvial].[Tokens] 
	 AS [int]
	 START WITH 1
	 INCREMENT BY 1
	 MINVALUE 1
	 MAXVALUE 2147483647
	 CYCLE 
	 CACHE 
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF object_id('[Alluvial].[AcquireLease]') IS NULL
	exec('CREATE PROCEDURE [Alluvial].[AcquireLease] AS SELECT 1')
GO

ALTER PROCEDURE [Alluvial].[AcquireLease]
	@scope nvarchar(50),
	@waitIntervalMilliseconds int = 5000, 
	@leaseDurationMilliseconds int = 60000
	AS
	BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

	DECLARE @resourceName nvarchar(50)
	DECLARE @now datetimeoffset
	DECLARE @token int

	SELECT @token = NEXT VALUE FOR Tokens
	SELECT @now = SYSDATETIMEOFFSET()
	
	BEGIN TRAN

	SELECT @resourceName = (SELECT TOP 1 ResourceName FROM Leases WITH (XLOCK,ROWLOCK)
		WHERE 
			Scope = @scope
				AND 
			(Expires IS NULL OR Expires < @now) 
				AND 
			DATEADD(MILLISECOND, @waitIntervalMilliseconds, LastReleased) < @now 
			ORDER BY LastReleased)

	UPDATE Leases
		SET LastGranted = @now,
			Expires = DATEADD(MILLISECOND, @leaseDurationMilliseconds, @now),
			Token = @token
		WHERE 
			ResourceName = @resourceName
				AND 
			Scope = @scope

	COMMIT TRAN

	SELECT * FROM Leases 
	WHERE ResourceName = @resourceName 
	AND Token = @token

	END


GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF object_id('[Alluvial].[ExtendLease]') IS NULL
	exec('CREATE PROCEDURE [Alluvial].[ExtendLease] AS SELECT 1')
GO

ALTER PROCEDURE [Alluvial].[ExtendLease]
	@resourceName nvarchar(50),
	@byMilliseconds int, 
	@token int  
	AS
	BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

	BEGIN TRAN

	DECLARE @expires datetimeoffset(7)

	SELECT @expires = 
	(SELECT Expires FROM Leases WITH (XLOCK,ROWLOCK)
		WHERE 
			ResourceName = @resourceName 
				AND 
			Token = @token)

	UPDATE Leases
		SET Expires = DATEADD(MILLISECOND, @byMilliseconds, @expires)
		WHERE 
			ResourceName = @resourceName 
				AND 
			Token = @token
				AND 
			Expires >= SYSDATETIMEOFFSET()

	IF @@ROWCOUNT = 0
		BEGIN
			ROLLBACK TRAN;
			THROW 50000, 'Lease could not be extended', 1;
		END
	ELSE
		COMMIT TRAN;
	END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF object_id('[Alluvial].[ReleaseLease]') IS NULL
	exec('CREATE PROCEDURE [Alluvial].[ReleaseLease] AS SELECT 1')
GO

ALTER PROCEDURE [Alluvial].[ReleaseLease]
	@resourceName nvarchar(50)  , 
	@token int  
	AS
	BEGIN
	SET NOCOUNT ON;

	DECLARE @now DATETIMEOFFSET(7)
	SELECT @now = SYSDATETIMEOFFSET()

	UPDATE Leases
	SET LastReleased = @now,
	    Expires = null
	WHERE ResourceName = @resourceName 
	AND Token = @token

	SELECT LastReased = @now

	END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



IF object_id('[Alluvial].[Leases]') IS NULL
BEGIN
	CREATE TABLE [Alluvial].[Leases](
		[ResourceName] [nvarchar](50) NOT NULL,
		[Scope] [nvarchar](50) NOT NULL,
		[LastGranted] [datetimeoffset](7) NULL,
		[LastReleased] [datetimeoffset](7) NULL,
		[Expires] [datetimeoffset](7) NULL,
		[Token] [int] NULL,
	 CONSTRAINT [PK_Leases_1] PRIMARY KEY CLUSTERED 
	(
		[ResourceName] ASC,
		[Scope] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]

	CREATE NONCLUSTERED INDEX [IX_Leases.Token] ON [Alluvial].[Leases]
	(
		[Token] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
END
GO

USE [master]
GO
ALTER DATABASE [AlluvialSqlDistributor] SET  READ_WRITE 
GO
