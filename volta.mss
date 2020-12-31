#enedis_lignes { 
    line-width: 2;
    line-color: magenta;
    [ ht = true ] {
        line-width: 6;
        line-join: round;
        line-cap: round;
    }
    [ underground = true ] {
        line-dasharray: 6,18 ;
        b/line-width: 0.5;
        b/line-color: magenta;
    }
}

#enedis_postes {
    marker-width: 8;
    marker-fill: blue;
    [ source = true ] {
        marker-width: 24;
    }
}


#rte_lignes_aeriennes { 
    ::line {
        line-width: 8;
        line-join: round;
        line-cap: round;
        line-color: darken(magenta,10%);
        b/line-width: 0.5;
        [ etat != 'EN EXPLOITATION' ] {
            line-opacity: 0.5;
        }
    }

    ::text {
        text-name: "[nom_ligne]";
        text-fill: darken(magenta,10%);
        text-face-name: @bold-fonts;
        text-halo-radius: 1.5;
        text-placement: line;
        text-dy: 5;
        text-wrap-width: 50;
        b/text-name: "[libelle]";
        b/text-fill: darken(magenta,10%);
        b/text-face-name: @bold-fonts;
        b/text-halo-radius: 1.5;
        b/text-placement: line;
        b/text-dy: -5;
    }
}

#rte_lignes_souterrainnes { 
    ::line {
        line-width: 8;
        line-join: round;
        line-cap: round;
        line-color: darken(magenta,10%);
        line-dasharray: 10,20;
        b/line-width: 0.5;
        [ etat != 'EN EXPLOITATION' ] {
            line-opacity: 0.5;
        }
    }

    ::text {
        text-name: "[nom_ligne]";
        text-fill: darken(magenta,10%);
        text-face-name: @bold-fonts;
        text-halo-radius: 1.5;
        text-placement: line;
        text-dy: 5;
        text-wrap-width: 50;
        b/text-name: "[libelle]";
        b/text-fill: darken(magenta,10%);
        b/text-face-name: @bold-fonts;
        b/text-halo-radius: 1.5;
        b/text-placement: line;
        b/text-dy: -5;
    }
}

#rte_enceintes_de_poste {
    line-color: darken(magenta,20%);
    line-width: 2;
    text-name: "[nom_poste]";
    text-fill: darken(magenta,10%);
    text-face-name: @bold-fonts;
    text-halo-radius: 1.5;
    text-wrap-width: 50;
}

#rte_pylones {
    marker-fill: black;
    marker-width: 8;
    text-name: "[numero_pylone]";
    text-face-name: @bold-fonts;
    text-halo-radius: 1.5;
    text-dy: -6;
    b/text-name: "[libelle]";
    b/text-face-name: @bold-fonts;
    b/text-halo-radius: 1.5;
    b/text-dy: 6;
}

#ore_distributeurs {
    line-color: white;
    text-name: "[grd_elec]";
    text-face-name: @bold-fonts;
    text-fill: magenta;
    text-halo-radius: 1.5;
    text-dy: -6;
    text-wrap-width: 20;
    text-placement: line;
    text-spacing: 400;
}