// Shared by the workshop and the game, served from the same origin.
(() => {
  const db = new Promise((resolve, reject) => {
    const open = indexedDB.open("cc-workshop", 1);
    open.onupgradeneeded = () => {
      for (const name of ["faces", "files"]) open.result.createObjectStore(name);
    };
    open.onsuccess = () => resolve(open.result);
    open.onerror = () => reject(open.error);
  });
  async function access(store, operation, write = false) {
    const connection = await db;
    return new Promise((resolve, reject) => {
      const tx = connection.transaction(store, write ? "readwrite" : "readonly");
      const request = operation(tx.objectStore(store));
      tx.oncomplete = () => resolve(request.result);
      tx.onabort = () => reject(tx.error);
    });
  }
  const cache = new Map();
  window.CCArt = { access, getFace: key => cache.get(key) || "" };
  db.then(database => {
    const cursor = database.transaction("faces").objectStore("faces").openCursor();
    cursor.onsuccess = () => {
      const entry = cursor.result;
      if (entry) { cache.set(entry.key, entry.value); entry.continue(); }
    };
  }).catch(console.error);
})();
