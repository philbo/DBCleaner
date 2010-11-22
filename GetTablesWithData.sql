/*
	This script generates a list of DELETE FROM statements
	for any table in your DB that have records
*/

SET NOCOUNT ON 

DECLARE @SQL VARCHAR(255) 
SET @SQL = 'DBCC UPDATEUSAGE (' + DB_NAME() + ')' 
EXEC(@SQL) 

CREATE TABLE #foo 
( 
    tablename VARCHAR(255), 
    rc INT 
) 
 
INSERT #foo 
    EXEC sp_msForEachTable 
        'SELECT PARSENAME(''?'', 1), 
        COUNT(*) FROM ?' 

SELECT 'delete from ' + tablename, rc 
    FROM #foo 
	where rc > 0
    ORDER BY rc DESC 

DROP TABLE #foo 