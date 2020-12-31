# Volta (cartocss)

Style mapnik destiné à un rendu raster transparent pour aider à la cartographie des réseaux électriques.

Données utilisées:
- RTE: lignes hautes-tension et postes électriques
- Enedis: lignes haute et basse tensions, postes source et postes électriques
- ORE: liste des distributeurs pas commune

## Script import.sh

- récupère la dernière version des données
- importe les données dans une base postgresql/potgis
- réorganise les données (une table pour toutes les lignes Enedis, une pour les postes)
- il optimise le stockage (CLUSTER géographique)

