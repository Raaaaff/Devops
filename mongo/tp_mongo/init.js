db = db.getSiblingDB('blog_db');

db.createCollection("posts", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["titre", "auteur", "vues"],
      properties: {
        titre:  { bsonType: "string" },
        auteur: { bsonType: "string" },
        vues:   { bsonType: "int" }
      }
    }
  }
});

db.posts.insertMany([
  { titre: "Article 1", auteur: "Oulala", vues: 10 },
  { titre: "Article 2", auteur: "Heuuuu",   vues: 27 },
  { titre: "Article 3", auteur: "Je sais pas", vues: 8  },
  { titre: "Article 4", auteur: "Tobogant", vues: 7 },
  { titre: "Article 5", auteur: "Coton Tige",   vues: 1756 }
]);
