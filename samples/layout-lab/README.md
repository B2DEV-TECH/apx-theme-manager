# Original synthetic Layout Lab

This sample was created for APEX Theme Manager. Project names, people and contact
values are invented. It has two authenticated Universal Theme pages, three
content regions, six form items and two navigation buttons, plus the generated
login page. It has no application tables, business data or external service calls.
Both variants also define an original `DEMO_VIEWER` access-control role so tests
can prove runtime ACL assignments survive definition recovery. The fixtures do
not ship an assigned user or an authentication credential.

`baseline/` and `changed/` are authorable APEXlang variants. The official SQLcl
compiler validated both and imported them into the new local sample application,
ID 105. Public APEX metadata confirmed identical region, item and button IDs across
both imports. IDs 105 and 104 identify this project's local sample and manager;
they are not discovery targets or assumptions about another installation.

`exports/baseline/f105.sql` and `exports/changed/f105.sql` are complete,
Oracle-generated SQL exports. The scripts below include these files unchanged
and use public `APEX_APPLICATION_INSTALL` context to choose the destination.
The source filename `f105.sql` does not select the installed application ID.

Install the manager/core first using the [installation guide](../../docs/installation/README.md).
Use exact APEX 26.2.0, a disposable development workspace, and a fresh SQL*Plus
connection as its parsing-schema owner. The scripts commit their own imports;
run them without unrelated pending work. SQL*Plus is the verified client for
these bind-based scripts; SQLcl 26.3 has a documented configuration-script
error-handler limitation. Start the client in the repository root. Connect with
`connect <schema>@<connect_identifier>` and enter the password at its prompt.

Declare the destination and output binds. Replace `<workspace_id>` with your
existing workspace's numeric ID; the public API allocates a new application ID:

```sql
variable apxtm_workspace_id number
variable apxtm_sample_app_id number
variable apxtm_sample_offset number
begin
  :apxtm_workspace_id := <workspace_id>;
  apex_util.set_security_group_id(:apxtm_workspace_id);
  apex_application_install.generate_application_id;
  :apxtm_sample_app_id := apex_application_install.get_application_id;
end;
/
@installer/install_sample.sql
select to_char(:apxtm_sample_app_id,'TM9') sample_application_id,
       to_char(:apxtm_sample_offset,'TM9') sample_offset
from dual;
```

The installer refuses an existing application ID, generates a new component
offset, and saves the exact public `GET_OFFSET` result in `apxtm_sample_offset`
before importing. Save both returned numbers outside the SQL*Plus session as
exact decimal values; `TO_CHAR(...,'TM9')` avoids rounded scientific display of
the long offset. The installed name is `APXTM Layout Lab`; its exact alias
is `APXTM-LAYOUT-LAB-<installed_application_id>` so several disposable samples can
coexist in one workspace. An independent export and two public item-ID/layout
checks verify the installation after its commit.

Reconnect as the same owner before registration. Redeclare the numeric binds
and restore the saved application ID and offset; reconnecting clears binds:

```sql
variable apxtm_workspace_id number
variable apxtm_sample_app_id number
variable apxtm_sample_offset number
variable apxtm_target_app_id number
variable apxtm_sample_snapshot_id number
begin
  :apxtm_workspace_id := <same_workspace_id>;
  :apxtm_sample_app_id := <installed_application_id>;
  :apxtm_sample_offset := <exact_saved_offset>;
  :apxtm_target_app_id := :apxtm_sample_app_id;
end;
/
@installer/register_application.sql
begin
  :apxtm_sample_snapshot_id := apxtm_engine.take_snapshot(
    :apxtm_sample_app_id, 'Synthetic baseline before changed sample');
end;
/
print apxtm_sample_snapshot_id
```

Registration remains read-only. You can also capture the baseline through the
manager's Applications page. Save the snapshot ID, then deliberately replace
only this disposable sample with the changed definition:

```sql
variable apxtm_sample_confirmation varchar2(300)
begin
  :apxtm_sample_confirmation := 'CHANGE SAMPLE <installed_application_id>';
end;
/
@samples/layout-lab/apply_changed.sql
```

Type the actual installed ID in the confirmation phrase. The workspace, sample
ID and saved offset binds must still contain the original values. If using a
new connection, redeclare and restore them first. The changed script checks the
exact name, alias, owner, workspace and these original public component IDs
before allowing an overwrite:

| Item | Required installed ID |
| --- | --- |
| `P1_PROJECT` on page 1 | `7405520579042701 + saved_offset` |
| `P2_SUMMARY` on page 2 | `7406228470042704 + saved_offset` |

It explicitly reuses the saved offset with `SET_OFFSET`; it never generates or
derives another offset. A missing or wrong offset/confirmation is refused.
This imports the complete changed synthetic definition and replaces any later
edits to that sample. It does not preserve arbitrary runtime changes made to
the disposable sample. The wrapper commits and independently checks the two
preserved IDs and changed spans. An import is not an atomic rollback operation.

Reconnect before comparison, then select the installed sample and saved
baseline snapshot in the manager. The controlled comparison has twelve eligible
changed scalars and two dropped explicit parameters that remain detection-only.
Recovery stays disabled until the owner separately enables that target through
the documented recovery policy. Preserve the baseline and use this disposable
sample to inspect preview and confirmation before enabling any recovery.

Only these source layout values differ:

| Page | Component | Property | Baseline | Changed |
| --- | --- | --- | --- | --- |
| 1 | Project brief region | Column span | 6 | 8 |
| 1 | Contact details region | Column span | 6 | 4 |
| 1 | Contact details region | Column | 7 | 9 |
| 1 | P1_PROJECT | Column span | 6 | 12 |
| 1 | P1_OWNER | Start new row | false | true |
| 1 | P1_OWNER | Column | 7 | 1 |
| 1 | P1_EMAIL | Column span | 6 | 12 |
| 1 | P1_EMAIL | Start new row | false | true |
| 1 | P1_EMAIL | Column | 7 | 1 |
| 1 | OPEN_REVIEW | Column span | 3 | 4 |
| 2 | P2_SUMMARY | Column span | 6 | 9 |
| 2 | P2_STATUS | Column span | 6 | 3 |
| 2 | P2_STATUS | Column | 7 | 10 |
| 2 | BACK_TO_DESK | Column span | 3 | 4 |

The SQL exporter may omit defaults or metadata irrelevant to a component's
rendering position. The comparison engine must derive eligibility from actual
exported properties, rather than treating this source table as permission to
patch an absent SQL parameter.

The baseline and changed SQL files retain the standard Oracle export wrappers.
Do not edit the generated wrappers or execute extracted internal component calls.
