// Family Tree Neo4j Initialization Script - Rivillas/Magalhaes Family
// Run this script in Neo4j Browser or cypher-shell to set up the family tree schema

// Create constraints for unique identifiers
CREATE CONSTRAINT person_name IF NOT EXISTS FOR (p:Person) REQUIRE p.name IS UNIQUE;

// Create indexes for better query performance
CREATE INDEX person_birth_date IF NOT EXISTS FOR (p:Person) ON (p.birth_date);
CREATE INDEX person_location IF NOT EXISTS FOR (p:Person) ON (p.location);
CREATE INDEX person_occupation IF NOT EXISTS FOR (p:Person) ON (p.occupation);

// Create the Rivillas/Magalhaes family tree data
// Juan Pablo and Alessandra (the main couple)
CREATE (juan:Person {
  name: "Juan Pablo Rivillas Ospina",
  birth_date: date("1991-11-18"),
  death_date: null,
  bio: "Loves to travel with his family, learn about new technologies and write in his blog. He's originally from Colombia but moved to Brazil in 2013. After that, has has lived in the United States for a year and today he spends most of the time with his family in their beach house in Sao Miguel dos Milagres. Coffee lover, tail teller and a very empathetic person. His family is his everything.",
  occupation: "Software Engineer",
  location: "Belo Horizonte, Brazil"
});

CREATE (alessandra:Person {
  name: "Alessandra Magalhes de Souza Lima",
  birth_date: date("1985-12-05"),
  death_date: null,
  bio: "Passionate mother. Loves to spend time with her family, traveling and discovering new places in the nature. She's a natural dreamer. What she visions, she makes happen. Dedicated mother and wife. A woman that conquers anybody's heart with her smile, kindness and contagious laugh.",
  occupation: "Lawyer",
  location: "Belo Horizonte, Brazil"
});

// Their children
CREATE (joao:Person {
  name: "Joao Rivillas de Magalhaes",
  birth_date: date("2021-06-11"),
  death_date: null,
  bio: "A very curious child. Loves to ride his bike with his brother David, go to the beach to grab crabs and travel with his family. The world is his home.",
  occupation: "None",
  location: "Belo Horizonte, Brazil"
});

CREATE (david:Person {
  name: "David Rivillas de Magalhaes",
  birth_date: date("2022-07-22"),
  death_date: null,
  bio: "Funniest child. Loves to ride his bike with his brother Joao, go to the beach to grab crabs. He loves animals and loves any adventure with his brother. He's very smart and loves to explore the nature, ask questions and look at the sky.",
  occupation: "None",
  location: "Belo Horizonte, Brazil"
});

// Juan Pablo's parents
CREATE (rolsalba:Person {
  name: "Rolsalba del Consuelo Ospina Montoya",
  birth_date: date("1956-07-24"),
  death_date: null,
  bio: "Dedicated mother and daughter. Strong woman who raised three boys on her own for many years. Loves a crossword puzzle, reading the three musketeers and enjoying a cup of coffee in the morning.",
  occupation: "None",
  location: "Rionegro, Antioquia, Colombia"
});

CREATE (tulio:Person {
  name: "Tulio Mario Rivillas Zapata",
  birth_date: date("1953-02-03"),
  death_date: null,
  bio: "Thing of a tough, hardworking person. Dedicated his life to his family. Moved to the US many years ago to provide for his family. Endured the hardest challenges in life, fell countless times, and never gave up. Today he lives in the US with his wife and daughter.",
  occupation: "Driver",
  location: "Adisson, IL, United States"
});

// Alessandra's parents
CREATE (cleolice:Person {
  name: "Cleolice Magalhaes de Souza Lima",
  birth_date: date("1948-06-29"),
  death_date: null,
  bio: "The biggest hearh in the family. She loves sitting on the kitchen's table and talk with whomever is there. Give her a cup of coffee and a slice of cheese and you'll have the best friend you ever need. Loves fishing and traveling with her family. Spends her day chasing her grandchildren, Joao and David.",
  occupation: "Retired Lawyer",
  location: "Belo Horizonte, Brazil"
});

// Note: Evaldo de Souza Lima is mentioned in relationships but not in the main data
// Creating him based on relationship info
CREATE (evaldo:Person {
  name: "Evaldo de Souza Lima",
  birth_date: null,
  death_date: null,
  bio: "Father of Alessandra and Izabela. Details to be added.",
  occupation: null,
  location: "Belo Horizonte, Brazil"
});

// Alessandra's sister
CREATE (izabela:Person {
  name: "Izabela Magalhaes de Souza Lima",
  birth_date: date("1990-08-10"),
  death_date: null,
  bio: "A very special person. She loves painting, reading, and spending time near her family. The most empathetic person in the family. She unites everyone with her smile and her kindness. Spends her day chasing her nephews, Joao and David, as well as enduring his brother in law Juan Pablo.",
  occupation: "None",
  location: "Belo Horizonte, Brazil"
});

// Create relationships based on the actual family data
// Marriage - Juan Pablo and Alessandra
MATCH (juan:Person {name: "Juan Pablo Rivillas Ospina"}), (alessandra:Person {name: "Alessandra Magalhes de Souza Lima"})
CREATE (juan)-[:MARRIED_TO]->(alessandra);

// Marriage - Cleolice and Evaldo (Alessandra's parents)
MATCH (cleolice:Person {name: "Cleolice Magalhaes de Souza Lima"}), (evaldo:Person {name: "Evaldo de Souza Lima"})
CREATE (cleolice)-[:MARRIED_TO]->(evaldo);

// Parent-Child relationships
// Juan Pablo's parents
MATCH (rolsalba:Person {name: "Rolsalba del Consuelo Ospina Montoya"}), (juan:Person {name: "Juan Pablo Rivillas Ospina"})
CREATE (rolsalba)-[:PARENT_OF]->(juan);

MATCH (tulio:Person {name: "Tulio Mario Rivillas Zapata"}), (juan:Person {name: "Juan Pablo Rivillas Ospina"})
CREATE (tulio)-[:PARENT_OF]->(juan);

// Alessandra's parents
MATCH (cleolice:Person {name: "Cleolice Magalhaes de Souza Lima"}), (alessandra:Person {name: "Alessandra Magalhes de Souza Lima"})
CREATE (cleolice)-[:PARENT_OF]->(alessandra);

MATCH (evaldo:Person {name: "Evaldo de Souza Lima"}), (alessandra:Person {name: "Alessandra Magalhes de Souza Lima"})
CREATE (evaldo)-[:PARENT_OF]->(alessandra);

// Izabela's parents (same as Alessandra's)
MATCH (cleolice:Person {name: "Cleolice Magalhaes de Souza Lima"}), (izabela:Person {name: "Izabela Magalhaes de Souza Lima"})
CREATE (cleolice)-[:PARENT_OF]->(izabela);

MATCH (evaldo:Person {name: "Evaldo de Souza Lima"}), (izabela:Person {name: "Izabela Magalhaes de Souza Lima"})
CREATE (evaldo)-[:PARENT_OF]->(izabela);

// Juan Pablo and Alessandra's children
MATCH (juan:Person {name: "Juan Pablo Rivillas Ospina"}), (joao:Person {name: "Joao Rivillas de Magalhaes"})
CREATE (juan)-[:PARENT_OF]->(joao);

MATCH (alessandra:Person {name: "Alessandra Magalhes de Souza Lima"}), (joao:Person {name: "Joao Rivillas de Magalhaes"})
CREATE (alessandra)-[:PARENT_OF]->(joao);

MATCH (juan:Person {name: "Juan Pablo Rivillas Ospina"}), (david:Person {name: "David Rivillas de Magalhaes"})
CREATE (juan)-[:PARENT_OF]->(david);

MATCH (alessandra:Person {name: "Alessandra Magalhes de Souza Lima"}), (david:Person {name: "David Rivillas de Magalhaes"})
CREATE (alessandra)-[:PARENT_OF]->(david);

// Verify the data
MATCH (p:Person) RETURN count(p) as total_people;
MATCH ()-[r]->() RETURN type(r) as relationship_type, count(r) as count ORDER BY count DESC;

// Sample queries to test the Rivillas/Magalhaes family tree
// 1. Find all descendants of Cleolice and Evaldo (Alessandra's parents)
MATCH (ancestor:Person)-[:PARENT_OF*]->(descendant:Person)
WHERE ancestor.name IN ["Cleolice Magalhaes de Souza Lima", "Evaldo de Souza Lima"]
RETURN ancestor.name as ancestor, descendant.name as descendant;

// 2. Find all siblings (Alessandra and Izabela, Joao and David)
MATCH (sibling1:Person)<-[:PARENT_OF]-(parent:Person)-[:PARENT_OF]->(sibling2:Person)
WHERE sibling1 <> sibling2
RETURN sibling1.name as person1, sibling2.name as person2, parent.name as parent;

// 3. Find all married couples
MATCH (person1:Person)-[m:MARRIED_TO]->(person2:Person)
RETURN person1.name as spouse1, person2.name as spouse2;

// 4. Find grandparents of Joao and David
MATCH (grandparent:Person)-[:PARENT_OF]->(parent:Person)-[:PARENT_OF]->(grandchild:Person)
WHERE grandchild.name IN ["Joao Rivillas de Magalhaes", "David Rivillas de Magalhaes"]
RETURN grandparent.name as grandparent, grandchild.name as grandchild, parent.name as parent;

// 5. Find all people by location
MATCH (p:Person)
RETURN p.location as location, collect(p.name) as people
ORDER BY location;

// 6. Find family members by occupation
MATCH (p:Person)
WHERE p.occupation IS NOT NULL AND p.occupation <> "None"
RETURN p.occupation as occupation, collect(p.name) as people
ORDER BY occupation;

RETURN "✅ Rivillas/Magalhaes family tree initialization completed successfully!" as status;
