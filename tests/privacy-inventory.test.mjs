import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("teknik gizlilik envanteri tum D1 tablolarini kapsar", async () => {
  const [schema, inventory] = await Promise.all([
    readFile(new URL("../db/schema.ts", import.meta.url), "utf8"),
    readFile(new URL("../docs/privacy-data-inventory.md", import.meta.url), "utf8"),
  ]);
  const tableNames = [...schema.matchAll(/sqliteTable\("([a-z0-9_]+)"/gu)]
    .map((match) => match[1]);
  assert.equal(tableNames.length, 27);
  assert.equal(new Set(tableNames).size, tableNames.length);
  for (const tableName of tableNames) {
    const marker = ["| `", tableName, "` |"].join("");
    assert.equal(inventory.includes(marker), true);
  }
});

test("envanter uygulanmis teknik purge ile acik hukuki saklama kararlarini ayirir", async () => {
  const inventory = await readFile(
    new URL("../docs/privacy-data-inventory.md", import.meta.url),
    "utf8",
  );
  assert.match(inventory, /Hukuki aydinlatma metni/);
  assert.match(inventory, /Production oncesi acik kararlar/);
  assert.match(inventory, /gunluk bakimda fiziksel silinir/);
  assert.match(inventory, /kesin saklama suresi hukuk\/operasyon karari bekler/);
  assert.match(inventory, /provider tokenlarini kalici saklamaz/);
  assert.match(inventory, /backend'i cihaz tokeni saklamaz/);
});
