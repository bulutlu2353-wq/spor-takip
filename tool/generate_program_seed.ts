// Kullanım: deno run --allow-read --allow-write tool/generate_program_seed.ts
import { PROGRAMS } from './programs.ts';
import { buildProgramSeedSql, validatePrograms } from './program_seed.ts';

const ids = new Set<string>(JSON.parse(await Deno.readTextFile('tool/data/exercise_ids.json')));
const errors = validatePrograms(PROGRAMS, ids);
if (errors.length > 0) {
  console.error(errors.join('\n'));
  Deno.exit(1);
}
await Deno.writeTextFile('supabase/migrations/0007_seed_programs.sql', buildProgramSeedSql(PROGRAMS));
console.log(`${PROGRAMS.length} program yazıldı.`);
