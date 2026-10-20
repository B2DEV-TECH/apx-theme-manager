import fs from 'node:fs/promises';
import { connect, statements } from './lib/oracle.mjs';
const connection = await connect();
let failed = 0;
let passed = 0;
try {
  const files = process.argv.slice(2);
  for (const file of files.length ? files : ['tests/parser.sql','tests/semantic.sql','tests/security.sql']) {
    const source = await fs.readFile(file, 'utf8');
    for (const [index, sql] of statements(source).entries()) {
      try { await connection.execute(sql); passed++; console.log(`PASS ${file} #${index+1}`); }
      catch (error) { failed++; console.error(`FAIL ${file} #${index+1}: ${error.message}`); }
    }
  }
  console.log(JSON.stringify({passed,failed}));
} finally { await connection.close(); }
process.exitCode = failed ? 1 : 0;
