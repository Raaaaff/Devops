USE ynov_ci;
CREATE TABLE utilisateurs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100),
    email VARCHAR(150),
    age INT,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO utilisateurs (nom, email, age) VALUES
    ('Alice Martin', 'alice.martin@ynov.com', 22),
    ('Baptiste Dupont', 'baptiste.dupont@ynov.com', 25),
    ('Camille Bernard', 'camille.bernard@ynov.com', 21);