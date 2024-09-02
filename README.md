# QueryAuditToolForMSSQL

Version 2.1

## Why Another Query Audit Tool?

The SQL client used by programs allows modification of the program name that appears in SQL connections. This can be useful, for example, to replace a generic engine name (such as an Apache or IIS server) with the name of the web application in the Dynamic Management View that lists active sessions. The same applies to the client machine name, which can be modified for practical reasons, especially when multiple instances of an application are running on different servers in a pool. In such cases, it is more relevant to see a name specific to the server pool rather than individual addresses.

However, SQL Server does not allow both the real source IP address and the substitution name provided at connection time to be obtained. This limitation also applies to the program name that sends the query. If this information were available simultaneously, this script would not be necessary.

None of the existing SQL audit tools address this issue:

- **SQL Profiler**, based on SQL Trace (now discouraged due to its performance impact).
- **Extended Events**, which replaces SQL Profiler, offering better performance and flexibility.
- **Server Audit**, based on Extended Events, and thus subject to the same limitations.

## How Does This Audit Tool Stand Out?

- Every audit tool must identify who made the query, which the tools mentioned above do. The connected user's name cannot be altered, which is essential for audit reliability.
- Although the program name behind the connection cannot be corrected, it is crucial to retrieve the source IP address of the query. Standard tools cannot provide this information directly, but it can be obtained via a login trigger that is installed with this tool.
- This tool combines and consolidates information from Extended Events (query, connection number, login name, execution time, event sequence) with the source IP address obtained from the login trigger.
- Reliable query auditing requires recording them on disk, allowing for later retrieval. Other audit targets may result in lost events.
- To ensure data retention, it is essential to manage audit files programmatically rather than allowing them to disappear with the "rollover" option. Without programmatic management, the disk may become full. The script handles the deletion of files whose contents have been processed.
- The continuous automation of file content retrieval provides a user-friendly interface in the form of a SQL table rather than requiring post-processing via XQuery in SQL. The query information is then reconciled with that intercepted by the login trigger.
- The final result is stored in a table, **dbo.AuditComplet**, within the **AuditReq** database. This storage is limited to 45 days to prevent indefinite growth of the database. Therefore, it is important to perform regular SQL backups.

This tool, deployable in a **[single SQL script available here](https://raw.githubusercontent.com/pelsql/QueryAuditToolForMSSql/main/QueryAuditToolForMSSql.sql)**, integrates several SQL automations for query auditing.

- It is based on the use of SQL Server Extended Events and a login trigger.
- It traces complete queries (excluding individual SQL module queries (stored procedures, functions, triggers), although this can be implemented at low cost).
- It logs the audit of queries, as well as the query's IP origin, the user who executed it, the time of completion, the program that launched it, and the database context in which it was executed.
- The trace is recorded in external files, retrieved and processed before being inserted into the database.
- The SQL script manages processed audit files and deletes them to avoid excessive space consumption.
- The final trace is stored in the **dbo.AuditComplet** table of the **AuditReq** database. This storage allows flexible querying using SQL filters.
- The trace processing task runs continuously via a SQL Agent job, scheduled to start with the server. The associated log is also stored in the **AuditReq** database. In case of interruption, the process is logged as an error in the SQL Agent job log, and the task is automatically restarted.
- The process retains the last 45 days of audit for immediate access. Long-term retention relies on regular backups, which are the responsibility of the DBA.
- Data integrity follows standard database management rules, such as choosing the recovery model and performing log backups. By default, the recovery model is full, requiring regular log backups, as is typically the case for most production databases.

### Successful Quality Tests:

- **Intensive Load Tests:** 20 simultaneous processes producing thousands of connections and queries (4,000 each), some reusing session numbers. These tests verified that the consolidation accounts for the temporal distance of events, correctly associating session information with the queries executed. The tool relies on the session number and event sequence specific to login events.
- **Forced Stop/Restart:** Resilience testing in case of interruption during intense processing. No audit file queries were lost during consolidation. All queries were verified to be present in the final audit.

### Future Improvement Plans:

- Trace individual SQL module queries.
- Add a pre-configuration mechanism for error reporting via email (with a choice of email server and recipients).

# Version History

- **Version 1.0:** Initial release (now obsolete).
- **Version 2.0:** Eliminated the need to store connection information in a table at the login trigger level, replacing the mechanism with the use of a user event containing the necessary information. Events are now sequenced to associate queries with their session number and event sequence. This method avoids the difficulties of linking by rounded temporal data at the trace file level.
- **Version 2.1:** Enhanced resilience to prevent event loss in case of interruption. Added a mechanism to prevent duplicate entries and implemented an automatic task restart every 15 minutes in case of stoppage. Support for multiple connections per session. Improved testing tools to simplify the verification of result accuracy, ensuring that no events are missing.
