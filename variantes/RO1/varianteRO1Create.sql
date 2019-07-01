CREATE OR REPLACE TYPE listTel AS TABLE of number(10);
/

CREATE TABLE Membre(
	numeroMembre number ,
	nom varchar(20) NOT NULL,
	prenom varchar(20)  NOT NULL,
	dateDeNaissance date NOT NULL,
	adresse varchar(128) ,
	telephone listTel,
	etatDossier number(1),
    PRIMARY KEY(numeroMembre)
)
NESTED TABLE telephone STORE AS TelMembre;
/

CREATE OR REPLACE TYPE typeJoueur AS OBJECT (
    numeroJoueur number(2),
    nom varchar(20),
    prenom varchar(20)
);
/

CREATE OR REPLACE TYPE listJoueurs AS TABLE OF typeJoueur;
/
CREATE OR REPLACE TYPE typeEquipe AS OBJECT (
    nomEquipe varchar(20),
    membres listJoueurs
);
/
 CREATE OR REPLACE TYPE listEquipe AS TABLE OF typeEquipe;
/

CREATE TABLE Activite(
	numeroActivite NUMBER(2) PRIMARY KEY,
	titreActivite varchar(50) NOT NULL,
	adresseActivite varchar(128)
);


CREATE TABLE Financement(
	numeroActivite NUMBER PRIMARY KEY REFERENCES Activite,
	dateActivite date,
	heureActivite number(4,2)
);

CREATE TABLE OrganisateurExterne(
	numeroOrganisateur NUMBER(2) PRIMARY KEY,
	nomOrganisateur varchar(30) NOT NULL,
	adresse varchar(128),
	nomResponsable varchar(30) NOT NULL,
	prenomResponsable varchar(30) NOT NULL,
	telephoneResponsable char(10) NOT NULL
);

CREATE TABLE Competition(
	numeroActivite NUMBER(2) PRIMARY KEY REFERENCES Activite,
	dateDebut date,
	dateFin date,
	lieuCompetition varchar(128),
	CHECK(dateDebut <= dateFin),
    equipes listEquipe
)
NESTED TABLE equipes STORE AS listeEquipes (NESTED TABLE membres STORE AS listeEquipe);
/

CREATE TABLE CompetitionExterne(
	numeroActivite NUMBER(2) PRIMARY KEY REFERENCES Competition,
	organisateurExterne NUMBER(2) NOT NULL REFERENCES OrganisateurExterne
);

CREATE TABLE CompetitionInterne(
	numeroActivite NUMBER(2) PRIMARY KEY REFERENCES Competition
);

CREATE TABLE Discipline(
	numeroDiscipline NUMBER(2) PRIMARY KEY,
	nomDiscipline varchar(20) NOT NULL
);

CREATE TABLE Specialite(
	numeroSpecialite NUMBER(2) PRIMARY KEY,
	nomSpecialite varchar(40) NOT NULL,
	discipline NUMBER(2) REFERENCES Discipline NOT NULL
);

CREATE TABLE Epreuve(
	competition NUMBER(2) REFERENCES Competition,
	numeroEpreuve NUMBER(2),
	dateEpreuve date NOT NULL,
	heureEpreuve number(4,2) NOT NULL,
	specialite NUMBER(2) REFERENCES Specialite,
	PRIMARY KEY (competition,numeroEpreuve)
);

CREATE TABLE Resultat(
	numeroResultat NUMBER(2),
	membre NUMBER(2) REFERENCES Membre,
	competitionEpreuve NUMBER(2),
	numeroEpreuve NUMBER(2),
	dateResultat date,
	rang NUMBER(2) NOT NULL,
	points NUMBER(2),
	PRIMARY KEY (numeroResultat,membre,competitionEpreuve,numeroEpreuve),
	FOREIGN KEY (competitionEpreuve,numeroEpreuve) REFERENCES Epreuve (competition,numeroEpreuve),
	UNIQUE (numeroEpreuve,competitionEpreuve,rang)
);

CREATE TABLE Inscription(
	numeroInscription NUMBER(2) PRIMARY KEY,
	anneeInscription char(4) NOT NULL,
	statutMembre varchar(20) NOT NULL,
	membre NUMBER(2) REFERENCES Membre NOT NULL
);

CREATE TABLE Paiement(
	numeroPaiement NUMBER(2) PRIMARY KEY,
	montantPaiement NUMBER(2) NOT NULL,
	inscription NUMBER(2) REFERENCES Inscription NOT NULL
);

CREATE TABLE Responsabilite(
	numeroMembre NUMBER(2) REFERENCES Membre,
	numeroActivite NUMBER(2) REFERENCES Activite,
	responsabiliteMembre varchar(200),
	PRIMARY KEY (numeroMembre,numeroActivite,responsabiliteMembre)
);

CREATE TABLE Specialisation(
	membre NUMBER(2) REFERENCES Membre,
	specialite NUMBER(2) REFERENCES Specialite,
	PRIMARY KEY (membre,specialite)
);

-- Vues permettant de reconstituer les classes li�es � des h�ritages qui ont disparu lors du passage � la MLD.
CREATE VIEW vFinancement AS
	SELECT a.numeroActivite, a.titreActivite, a.adresseActivite, f.dateActivite, f.heureActivite
	FROM Activite a
	INNER JOIN Financement f
	ON a.numeroActivite = f.numeroActivite;

CREATE VIEW vCompetition AS
	SELECT a.numeroActivite, a.titreActivite, a.adresseActivite, c.dateDebut, c.dateFin, c.lieuCompetition
	FROM Activite a
	INNER JOIN Competition c
	ON a.numeroActivite = c.numeroActivite;

CREATE VIEW vCompetitionInterne AS
	SELECT v.numeroActivite, v.titreActivite, v.adresseActivite, v.dateDebut, v.dateFin, v.lieuCompetition
	FROM vCompetition v
	INNER JOIN CompetitionInterne i
	ON i.numeroActivite = v.numeroActivite;

CREATE VIEW vCompetitionExterne AS
	SELECT v.numeroActivite, v.titreActivite, v.adresseActivite, v.dateDebut, v.dateFin, v.lieuCompetition, e.organisateurExterne
	FROM vCompetition v
	INNER JOIN CompetitionExterne e
	ON e.numeroActivite = v.numeroActivite;

-- Vues permettant de s'assurer des contraintes de la MCD d'abstraction des deux classes m�res et d'exclusivit� des deux h�ritages.
CREATE VIEW cActiviteAbstraite AS -- Les valeurs retourn�es par cette vue sont les num�ros d'activit�s qui n'apparaissent ni dans Financement ni dans Competition.
	SELECT a.numeroActivite "Activit� non instanci�e"
	FROM Activite a
	LEFT JOIN Financement f ON a.numeroActivite = f.numeroActivite
	LEFT JOIN Competition c ON a.numeroActivite = c.numeroActivite
	WHERE f.numeroActivite IS NULL AND c.numeroActivite IS NULL;

CREATE VIEW cActExcl AS -- Les valeurs retourn�es par cette vue sont les num�ros d'activit�s qui apparaissent � la fois dans Financement et dans Competition.
	SELECT f.numeroActivite "Activit� non exclusif"
	FROM Financement f 
	INNER JOIN Competition c ON f.numeroActivite = c.numeroActivite;

CREATE VIEW cCompetitionAbstraite AS -- Les valeurs retourn�es par cette vue sont les num�ros d'activit� des comp�titions qui n'apparaissent ni dans CompetitionInterne ni dans CompetitionExterne.
	SELECT c.numeroActivite "Comp�tition non instanci�e"
	FROM Competition c
	LEFT JOIN CompetitionInterne i ON c.numeroActivite = i.numeroActivite
	LEFT JOIN CompetitionExterne e ON c.numeroActivite = e.numeroActivite
	WHERE i.numeroActivite IS NULL AND e.numeroActivite IS NULL;

CREATE VIEW cCompetExcl AS -- Les valeurs retourn�es par cette vue sont les num�ros d'activit�s des comp�titions qui apparaissent � la fois dans CompetitionInterne et dans CompetitionExterne.
	SELECT i.numeroActivite "Comp�tition non exclusif"
	FROM CompetitionInterne i
	INNER JOIN CompetitionExterne e ON i.numeroActivite = e.numeroActivite;

CREATE VIEW vInscription AS
	SELECT numeroInscription, anneeInscription, statutMembre, membre, (
		CASE WHEN statutMembre = 'amateur' THEN 0
		ELSE 25
		END) fraisInscription
	FROM Inscription;
--Vues permettant de g�rer le solde.
CREATE VIEW vMembre AS
	SELECT m.numeroMembre, m.nom, m.prenom, m.dateDeNaissance, m.adresse, COALESCE(sum(i.fraisInscription),0)-COALESCE(sum(p.montantPaiement),0) solde
	FROM Membre m
	INNER JOIN vInscription i ON m.numeroMembre = i.membre
	LEFT JOIN Paiement p ON p.inscription = i.numeroInscription
	GROUP BY p.numeroPaiement,m.numeroMembre,m.nom, m.prenom, m.dateDeNaissance, m.adresse;


--RO--


