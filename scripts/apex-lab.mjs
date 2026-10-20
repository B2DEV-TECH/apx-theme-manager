import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { connect, localConfig, oracledb } from './lib/oracle.mjs';

const [command, ...args] = process.argv.slice(2);
const config = await localConfig();
const sqlcl = path.resolve('.local/tools/sqlcl/bin/sql.exe');

if (command === 'sqlcl') {
  const source = await fs.readFile(args[0], 'utf8');
  const child = spawn(sqlcl, ['-thin', '-s', '-nolog'], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
  // Credentials travel over stdin and are never printed, persisted, or placed in argv.
  let output = '';
  for (const stream of [child.stdout, child.stderr]) stream.on('data', x => { output += x; });
  child.stdin.end(`set echo off\nset define off\nconnect ${config.user}/"${config.password.replaceAll('"', '""')}"@${config.connectString}\n${source}\nexit\n`);
  const code = await new Promise(resolve => child.on('close', resolve));
  output = output.replaceAll(config.password, '[REDACTED]');
  process.stdout.write(output);
  if (code || /(?:ORA-|PLS-|Error:|Connection failed|Validation failed|invalid syntax)/i.test(output)) process.exitCode = code || 1;
} else if (command === 'export') {
  const id = Number(args[0]);
  const directory = path.resolve(args[1]);
  const format = args[2] || 'SQL';
  if (!Number.isSafeInteger(id) || id <= 0) throw new Error('Explicit application ID required');
  const db = await connect();
  try {
    const exports = await db.execute(`declare
      files apex_t_export_files;
      data json_array_t := json_array_t();
      entry json_object_t;
    begin
      apex_util.set_workspace(:workspace);
      files := apex_export.get_application(p_application_id => :id, p_type => :format,
        p_with_date => false, p_with_audit_info => null, p_with_supporting_objects => 'N');
      for i in 1 .. files.count loop
        entry := json_object_t();
        entry.put('name', files(i).name);
        if files(i).contents_blob is not null then
          entry.put('binary', apex_web_service.blob2clobbase64(files(i).contents_blob));
        else
          entry.put('text', files(i).contents);
        end if;
        data.append(entry);
      end loop;
      :result := data.to_clob;
    end;`, { workspace: config.workspace, id, format,
      result: { dir: oracledb.BIND_OUT, type: oracledb.CLOB } });
    const entries = JSON.parse(await exports.outBinds.result.getData());
    for (const entry of entries) {
      const target = path.resolve(directory, entry.name);
      if (!target.startsWith(directory + path.sep)) throw new Error('Export file escaped destination');
      await fs.mkdir(path.dirname(target), { recursive: true });
      await fs.writeFile(target, entry.binary ? Buffer.from(entry.binary, 'base64') : entry.text.replaceAll('\r\n', '\n'));
    }
    console.log(JSON.stringify({ applicationId: id, format, files: entries.length, directory }));
  } finally { await db.close(); }
} else if (command === 'allocate') {
  const db = await connect();
  try {
    const result = await db.execute(`begin apex_util.set_workspace(:workspace);
      apex_application_install.generate_application_id;
      :id := apex_application_install.get_application_id; end;`, {
      workspace: config.workspace, id: { dir: oracledb.BIND_OUT, type: oracledb.NUMBER }
    });
    console.log(result.outBinds.id);
  } finally { await db.close(); }
} else {
  throw new Error('Usage: node scripts/apex-lab.mjs sqlcl <file> | export <id> <directory> [SQL|APEXLANG] | allocate');
}
