import fs from 'node:fs/promises';
import oracledb from 'oracledb';

oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;
oracledb.fetchAsString = [oracledb.CLOB];
oracledb.fetchAsBuffer = [oracledb.BLOB];

export async function localConfig() {
  const path = process.env.APXTM_LAB_CONFIG || new URL('../../.local/lab.json', import.meta.url);
  return JSON.parse((await fs.readFile(path, 'utf8')).replace(/^\uFEFF/, ''));
}

export async function connect() {
  const config = await localConfig();
  return oracledb.getConnection({ user: config.user, password: config.password,
    connectString: config.connectString });
}

// Deliberately limited to this project's SQL scripts; this is not a SQL*Plus parser.
export function statements(source) {
  return source.replace(/\r\n/g, '\n').split(/^\/\s*$/m).map(s => s.trim()).filter(Boolean);
}

export async function installFile(connection, path) {
  const source = await fs.readFile(path, 'utf8');
  for (const sql of statements(source)) await connection.execute(sql);
  const invalid = await connection.execute(`select name,type,line,position,text from user_errors
    where attribute='ERROR' order by name,sequence`);
  if (invalid.rows.length) throw new Error(JSON.stringify(invalid.rows));
}

export { oracledb };
