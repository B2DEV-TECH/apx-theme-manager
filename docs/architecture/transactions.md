# Transaction boundaries observed in APEX 26.2.0

The local laboratory uses Oracle AI Database 26ai Free 23.26.3.0.0 and APEX
26.2.0. These observations are specific to that environment.

`APEX_EXPORT.GET_APPLICATION` succeeded after pending DML in an independently
constructed test. ORA-01453 was **not reproduced**. No claim is made that other
releases or call contexts behave the same way.

`APEX_APPLICATION_INSTALL.INSTALL`, however, returned with a non-null
`DBMS_TRANSACTION.LOCAL_TRANSACTION_ID(false)`. Session-lock inspection showed
metadata TM locks and a TX lock. An explicit commit by the connection that owned
that synthetic fixture import cleared its TX and TM locks. Starting an autonomous
recovery operation from that importing connection before completing its import
transaction produced ORA-00060 at the public application-lock operation.

The engine therefore uses deliberate ownership boundaries:

1. A snapshot/comparison/recovery request runs in its own autonomous transaction.
   It cannot commit its caller's unrelated business DML.
2. Export runs in an isolated autonomous boundary with no preceding engine DML.
3. Recovery claims and verified backups are committed before installation.
4. The engine-owned import transaction is explicitly committed after INSTALL
   returns, before independently re-exporting the durable application state.
5. The final VERIFIED outcome is recorded only if the complete re-exported SQL
   fingerprint equals the approved artifact, including unrelated source.

The test suite checks snapshot transaction isolation with a second connection:
the observer cannot see the caller's pending update, while the snapshot is
durable and its artifact is deduplicated.

Developer scripts should finish their own application import transaction and
use a fresh session before calling the manager. Do not invoke recovery while
holding application metadata locks in a parent transaction. The APEX interface
manages a different target application and excludes itself as a recovery target.

An import can commit internally, fail partially or invalidate sessions. There is
no atomic rollback promise. FAILED/APPLYING operations require examination of the
target, durable backup and audit. A full definition restore is a new privileged
operation; runtime data and external dependencies are outside its scope.
