import { connect, installFile } from './lib/oracle.mjs';
const connection = await connect();
try {
  const [mode, ...args] = process.argv.slice(2);
  if (mode === 'install') {
    for (const file of args) { await installFile(connection, file); console.log(`Installed ${file}`); }
  } else if (mode === 'query') {
    const result = await connection.execute(args.join(' '));
    console.log(JSON.stringify(result.rows ?? result.outBinds ?? { rowsAffected: result.rowsAffected }, null, 2));
  } else throw new Error('Usage: node scripts/db.mjs install file... | query SQL');
} finally { await connection.close(); }
