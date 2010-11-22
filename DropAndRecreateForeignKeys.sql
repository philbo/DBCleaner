/*
	This script creates two lists of ALTER TABLE statements.
	The first set will drop any existing foreign keys in your DB
	and the second will readd them.
*/

DECLARE		 @constraint_name sysname,
			 @parent_schema sysname,
			 @parent_name sysname,
			 @referenced_object_schema sysname,
			 @referenced_object_name sysname,
			 @column_name sysname,
			 @referenced_column_name sysname,
			 @is_not_for_replication bit,
			 @is_not_trusted bit,
			 @delete_referential_action tinyint,
			 @update_referential_action tinyint,
			 @AddLine nvarchar(max),
			 @DropLine nvarchar(max),
			 @fkline nvarchar(max),
			 @pkline nvarchar(max),
			 @object_id int,
			 @parent_object_id int

DECLARE		@AddScript TABLE (line nvarchar(max))
DECLARE		@DropScript TABLE (line nvarchar(max))

SET NOCOUNT ON

 -- Create cursor for foreign keys system view
DECLARE cFKeys CURSOR READ_ONLY
FOR 
	 SELECT		 object_id, 
				 parent_object_id, 
				 OBJECT_SCHEMA_NAME(parent_object_id), 
				 object_name (parent_object_id), 
				 [name], 
				 is_not_trusted, 
				 OBJECT_SCHEMA_NAME(referenced_object_id), 
				 object_name(referenced_object_id),
				 delete_referential_action,
				 update_referential_action,
				 is_not_for_replication
				 
	 FROM		 sys.foreign_keys 
	 WHERE		 object_name (referenced_object_id) IN (select name from sys.tables where type = 'U')	
	 ORDER BY		[name]
  
 OPEN cFKeys
 
 -- Collect basic data
 FETCH NEXT FROM cFKeys INTO @object_id, @parent_object_id, @parent_schema, @parent_name, @constraint_name, @is_not_trusted, @referenced_object_schema, @referenced_object_name, @delete_referential_action, @update_referential_action, @is_not_for_replication
 WHILE (@@fetch_status <> -1)
 BEGIN
 IF (@@fetch_status <> -2)
 BEGIN
 -- Start creating command string. One for add and one for drop constraint
 SET @AddLine = N'ALTER TABLE ' + quotename(@parent_schema) + N'.' + quotename(@parent_name)
 SET @DropLine = N'ALTER TABLE ' + quotename(@parent_schema) + N'.' + quotename(@parent_name)
 -- Check if it is enabled or not
 IF @is_not_trusted = 1
 SET @AddLine = @AddLine + N' WITH NOCHECK'
 ELSE
 SET @AddLine = @AddLine + N' WITH CHECK'
 
 SET @AddLine = @AddLine + N' ADD CONSTRAINT ' + quotename(@constraint_name) + N' FOREIGN KEY (' 
 SET @DropLine = @DropLine + N' DROP CONSTRAINT ' + quotename(@constraint_name)
 
 -- Gather all columns for current key from foreign key columns system view
 DECLARE cColumns CURSOR READ_ONLY
 FOR 
 SELECT fc.name, pc.name
 FROM sys.foreign_key_columns fk 
 inner join sys.columns fc on fk.parent_object_id = fc.object_id and fk.parent_column_id = fc.column_id
 inner join sys.columns pc on fk.referenced_object_id = pc.object_id and fk.referenced_column_id = pc.column_id
 WHERE parent_object_id = @parent_object_id and fk.constraint_object_id = @object_id
 
 OPEN cColumns
 
 SET @fkline = N''
 SET @pkline = N''
 
 FETCH NEXT FROM cColumns INTO @column_name, @referenced_column_name
 WHILE (@@fetch_status <> -1)
 BEGIN
 IF (@@fetch_status <> -2)
 BEGIN
 -- One line for column list and one for referenced columns
 SET @fkline = @fkline + @column_name
 SET @pkline = @pkline + @referenced_column_name
 END
 FETCH NEXT FROM cColumns INTO @column_name, @referenced_column_name
 IF (@@fetch_status = 0)
 BEGIN
 SET @fkline = @fkline + ', '
 SET @pkline = @pkline + ', '
 END
 END
 
 CLOSE cColumns
 DEALLOCATE cColumns
 -- Add column list
 SET @AddLine = @AddLine + @fkline + N')' + CHAR(13) 
 -- Add referenced table and column list
 SET @AddLine = @AddLine + 'REFERENCES ' + quotename(@referenced_object_schema) + N'.' + quotename(@referenced_object_name) 
 SET @AddLine = @AddLine + N' (' + @pkline + N')'
 -- Check the referential action that was declared for this key as well as replication option
 SET @AddLine = @AddLine +
 CASE 
 WHEN @IS_NOT_FOR_REPLICATION = 1 THEN N' NOT FOR REPLICATION'
 ELSE N''
 END
 -- Insert command into table for later use
 INSERT INTO @DropScript SELECT @DropLine
 INSERT INTO @AddScript SELECT @AddLine
 
 FETCH NEXT FROM cFKeys INTO @object_id, @parent_object_id, @parent_schema, @parent_name, @constraint_name, @is_not_trusted, @referenced_object_schema, @referenced_object_name, @delete_referential_action, @update_referential_action, @is_not_for_replication
 END
 END
 
 CLOSE cFKeys
 DEALLOCATE cFKeys
 
 SET NOCOUNT OFF
 
 SELECT line FROM @DropScript
 SELECT line FROM @AddScript



