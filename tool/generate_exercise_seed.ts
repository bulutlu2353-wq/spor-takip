// Kullanım: deno run --allow-net --allow-write tool/generate_exercise_seed.ts [--chunks N]
// --chunks N: SQL Editor tek dosyayı kabul etmezse, aynı içeriği N parçaya bölüp
// tool/.out/ altına yazar (git'e girmez). Migration dosyası her durumda tek parça üretilir.
import { buildExerciseSeedSql } from './exercise_seed.ts';
import type { RawExercise } from './exercise_seed.ts';

export const DATASET_COMMIT = 'a859101d633a01c4a1a920d6a8ce41dabba0705f';
const url = `https://raw.githubusercontent.com/yuhonas/free-exercise-db/${DATASET_COMMIT}/dist/exercises.json`;

const response = await fetch(url);
if (!response.ok) throw new Error(`İndirilemedi: ${response.status}`);
const exercises = (await response.json()) as RawExercise[];
exercises.sort((a, b) => a.id.localeCompare(b.id));

await Deno.writeTextFile('supabase/migrations/0005_seed_exercises.sql', buildExerciseSeedSql(exercises));
await Deno.mkdir('tool/data', { recursive: true });
await Deno.writeTextFile('tool/data/exercise_ids.json', JSON.stringify(exercises.map((e) => e.id), null, 1) + '\n');

const chunkFlag = Deno.args.indexOf('--chunks');
if (chunkFlag >= 0) {
  const n = Number(Deno.args[chunkFlag + 1]);
  const size = Math.ceil(exercises.length / n);
  await Deno.mkdir('tool/.out', { recursive: true });
  for (let i = 0; i < n; i++) {
    const part = exercises.slice(i * size, (i + 1) * size);
    await Deno.writeTextFile(`tool/.out/0005_part${i + 1}.sql`, buildExerciseSeedSql(part));
  }
}
console.log(`${exercises.length} hareket yazıldı.`);
