----------------------------------------
-- 1)
----------------------------------------
-- ¿Para cada liga, en las ultimas tres temporadas cuales han sido las posiciones finales?
-- 3 puntos => ganar
-- 0 puntos => perder
-- 1 punto => empatar

-- 1.1) Identificar cuales fueron las ultimas 3 temporadas...
CREATE TABLE season_positions AS
WITH last_3_seasons AS (SELECT season,
                               RANK() OVER (
                                   ORDER BY season DESC
                                   )
                        FROM match
                        GROUP BY season
                        LIMIT 3),

     -- 1.2) Calcular los puntos obtenidos como local
     home_points AS (SELECT league_id,
                            season,
                            home_team_api_id AS team_api_id,
                            SUM(
                                    CASE
                                        WHEN home_team_goal > away_team_goal THEN 3
                                        WHEN home_team_goal = away_team_goal THEN 1
                                        WHEN home_team_goal < away_team_goal THEN 0
                                        END
                                )            AS points
                     FROM match
                     WHERE season IN (SELECT season FROM last_3_seasons)
                     GROUP BY league_id, season, home_team_api_id),

     -- 1.3) Calcular los puntos obtenidos como visitante
     away_points AS (SELECT league_id,
                            season,
                            away_team_api_id AS team_api_id,
                            SUM(
                                    CASE
                                        WHEN home_team_goal < away_team_goal THEN 3
                                        WHEN home_team_goal = away_team_goal THEN 1
                                        WHEN home_team_goal > away_team_goal THEN 0
                                        END
                                )            AS points
                     FROM match
                     WHERE season IN (SELECT season FROM last_3_seasons)
                     GROUP BY league_id, season, away_team_api_id),

     -- 1.3) Calcular los puntos totales
     total_points_t AS (SELECT league_id, season, team_api_id, SUM(points) as total_points
                        FROM (SELECT *
                              FROM away_points
                              UNION ALL
                              SELECT *
                              FROM home_points) AS total_points
                        GROUP BY league_id, season, team_api_id),

     --1.4) Generar la tabla de posiciones de cada temporada en cada una de las ligas...
     position_tables AS (SELECT team_api_id,
                                league_id,
                                season,
                                total_points,
                                RANK() OVER (
                                    PARTITION BY season, league_id
                                    ORDER BY total_points DESC
                                    ) season_position
                         FROM total_points_t)
SELECT *
FROM position_tables;

----------------------------------------
-- 2)
----------------------------------------
-- ¿Cuales serían las posiciones finales relativas para cada equipo partiendo de las tres ultimas temporadas?
CREATE TABLE relative_season_positions AS
SELECT team_api_id, league_id, AVG(total_points) AS avg_points, AVG(season_position) AS avg_position
FROM season_positions
GROUP BY team_api_id, league_id

----------------------------------------
-- 3)
----------------------------------------
-- Entonces ¿Cuáles son las ligas más competitivas?
-- Obtener medidas de dispersión básicas
WITH leagues_MofD AS (SELECT league_id,
                             COUNT(DISTINCT team_api_id)                              num_teams,
                             AVG(avg_points)                                          mean,
                             STDDEV(avg_points)                                       stddev,
                             MIN(avg_points)                                          min,
                             MAX(avg_points)                                          max,
                             MAX(avg_points) - MIN(avg_points)                        range,
                             PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_points)  median,
                             PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY avg_points) q1,
                             PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY avg_points) q3
                      FROM relative_season_positions
                      GROUP BY league_id)
     -- 3.3) Finalmente tengo que calcular la asimetría
SELECT league.name,
       num_teams,
       ROUND(mean, 2)                                  AS MEAN,
       ROUND(stddev, 2)                                AS STDDEV,
       ROUND(min, 2)                                   AS MIN,
       ROUND(max, 2)                                   AS MAX,
       ROUND(range, 2)                                 AS RANGE,
       ROUND(median::NUMERIC, 2)                       AS MEDIAN,
       ROUND(q1::NUMERIC, 2)                           AS Q1,
       ROUND(q3::NUMERIC, 2)                           AS Q3,
       ROUND(3 * (mean - median)::NUMERIC / stddev, 2) AS ASYMMETRY
FROM leagues_MofD
    JOIN league ON leagues_MofD.league_id = league.id;

----------------------------------------
-- 4)
----------------------------------------
CREATE TABLE dominant_teams AS
WITH relative_season_position_ranked AS (SELECT *,
                                                RANK() OVER (
                                                    PARTITION BY league_id
                                                    ORDER BY avg_position
                                                    ) position_rank
                                         FROM relative_season_positions),
     gaps AS (SELECT t1.position_rank as position_rank, t1.league_id as league_id
              FROM relative_season_position_ranked t1,
                   relative_season_position_ranked t2
              WHERE t1.position_rank = t2.position_rank - 1
                AND t1.league_id = t2.league_id
                AND (t1.league_id LIKE '1729' OR
                     t1.league_id LIKE '4769' OR
                     t1.league_id LIKE '7809' OR
                     t1.league_id LIKE '10257' OR
                     t1.league_id LIKE '21518')
                AND t1.avg_points - t2.avg_points >= 9)
SELECT *
FROM relative_season_position_ranked rspr
WHERE rspr.position_rank <= (SELECT MIN(position_rank) FROM gaps WHERE gaps.league_id = rspr.league_id)
  AND (league_id LIKE '1729' OR
       league_id LIKE '4769' OR
       league_id LIKE '7809' OR
       league_id LIKE '10257' OR
       league_id LIKE '21518');
       
----------------------------------------
-- 5)
----------------------------------------
-- Overall rating promedio y edad promedio de los jugadores de los equipos dominantes
WITH players AS (SELECT DISTINCT player, team_api_id
                 FROM (SELECT *,
                              home_team_api_id as team_api_id
                       FROM match
                       WHERE season LIKE '2015/2016'
                         AND home_team_api_id IN (SELECT team_api_id FROM dominant_teams)) t
                          CROSS JOIN LATERAL ( VALUES (home_player_1),
                                                      (home_player_2),
                                                      (home_player_3),
                                                      (home_player_4),
                                                      (home_player_5),
                                                      (home_player_6),
                                                      (home_player_7),
                                                      (home_player_8),
                                                      (home_player_9),
                                                      (home_player_10),
                                                      (home_player_11)
                     ) AS players (player)
                 UNION ALL
                 SELECT DISTINCT player, team_api_id
                 FROM (SELECT *,
                              away_team_api_id as team_api_id
                       FROM match
                       WHERE season LIKE '2015/2016'
                         AND away_team_api_id IN (SELECT team_api_id FROM dominant_teams)) t
                          CROSS JOIN LATERAL ( VALUES (away_player_1),
                                                      (away_player_2),
                                                      (away_player_3),
                                                      (away_player_4),
                                                      (away_player_5),
                                                      (away_player_6),
                                                      (away_player_7),
                                                      (away_player_8),
                                                      (away_player_9),
                                                      (away_player_10),
                                                      (away_player_11)
                     ) AS players (player)),
     player_in_top_teams AS (SELECT DISTINCT player, team_api_id
                             FROM players)
SELECT t.team_long_name,
       ROUND(AVG(EXTRACT(YEAR FROM AGE(CURRENT_TIMESTAMP, p.birthday))), 2),
       ROUND(AVG(pa.overall_rating), 2)
FROM player_in_top_teams pitt
         INNER JOIN player p ON p.player_api_id = pitt.player
         INNER JOIN player_attributes pa on pa.player_api_id = pitt.player
         JOIN team t ON t.team_api_id = pitt.team_api_id
GROUP BY t.team_long_name;


----------------------------------------
-- 6)
----------------------------------------
-- ¿Cuál es el equipo dominante que ha tenido la mayor posesión del balón durante las últimas tres temporadas?
WITH last_3_seasons AS (SELECT season,
                               RANK() OVER (
                                   ORDER BY season DESC
                                   )
                        FROM match
                        GROUP BY season
                        LIMIT 3),
     possession_dominant_teams AS (SELECT dt.team_api_id, AVG(p.home_possession) AS avg_possession
                                   FROM dominant_teams dt
                                            INNER JOIN match m on dt.team_api_id = m.home_team_api_id
                                            INNER JOIN possession p on m.match_api_id = p.match_api_id
                                   WHERE m.season IN (SELECT season FROM last_3_seasons)
                                   GROUP BY dt.team_api_id
                                   UNION ALL
                                   SELECT dt.team_api_id, AVG(p.away_possession) AS avg_possession
                                   FROM dominant_teams dt
                                            INNER JOIN match m on dt.team_api_id = m.away_team_api_id
                                            INNER JOIN possession p on m.match_api_id = p.match_api_id
                                   WHERE m.season IN (SELECT season FROM last_3_seasons)
                                   GROUP BY dt.team_api_id)
SELECT team.team_long_name           AS "Club",
       ROUND(AVG(avg_possession), 2) AS "Posesión",
       RANK() OVER (
           ORDER BY AVG(avg_possession) DESC
           )                            "Rank Posesión"
FROM possession_dominant_teams
         JOIN team ON possession_dominant_teams.team_api_id = team.team_api_id
GROUP BY team.team_long_name;


----------------------------------------
-- 7)
----------------------------------------
-- ¿Cuál es el equipo dominante que ha anotado la mayor cantidad de goles en los primeros 15 minutos de un partido en las últimas tres temporadas?
WITH last_3_seasons AS (SELECT season,
                               RANK() OVER (
                                   ORDER BY season DESC
                                   )
                        FROM match
                        GROUP BY season
                        LIMIT 3),
     goals_over_15_t AS (SELECT dt.team_api_id, COUNT(*) as goals_over_15
                         FROM dominant_teams dt
                                  INNER JOIN match m on dt.team_api_id = m.home_team_api_id
                                  INNER JOIN goals g on m.match_api_id = g.match_api_id
                         WHERE m.season IN (SELECT season FROM last_3_seasons)
                           AND g.team_api_id = dt.team_api_id
                           AND g.minute <= 15
                         GROUP BY dt.team_api_id
                         UNION ALL
                         SELECT dt.team_api_id, COUNT(*) as goals_over_15
                         FROM dominant_teams dt
                                  INNER JOIN match m on dt.team_api_id = m.away_team_api_id
                                  INNER JOIN goals g on m.match_api_id = g.match_api_id
                         WHERE m.season IN (SELECT season FROM last_3_seasons)
                           AND g.team_api_id = dt.team_api_id
                           AND g.minute <= 15
                         GROUP BY dt.team_api_id)
SELECT team.team_long_name                AS "Club",
       SUM(goals_over_15_t.goals_over_15) AS "Goles antes de los 15 min",
       RANK() OVER (
           ORDER BY SUM(goals_over_15_t.goals_over_15) DESC
           )                                 "Rank Goles..."
FROM goals_over_15_t
         JOIN team ON goals_over_15_t.team_api_id = team.team_api_id;

----------------------------------------
-- 8)
----------------------------------------
-- ¿Cuál es el equipo dominante cuyos jugadores han incurrido en menos faltas en las últimas tres temporadas?
WITH last_3_seasons AS (SELECT season,
                               RANK() OVER (
                                   ORDER BY season DESC
                                   )
                        FROM match
                        GROUP BY season
                        LIMIT 3),
     team_total_faults AS (SELECT team_api_id, SUM(num_faults) AS total_faults
                           FROM ((SELECT match.home_team_api_id  AS team_api_id,
                                         SUM(faults.home_faults) AS num_faults
                                  FROM match
                                           RIGHT JOIN faults ON match.match_api_id = faults.match_api_id
                                  WHERE match.season IN (SELECT season FROM last_3_seasons)
                                  GROUP BY match.home_team_api_id)
                                 UNION ALL
                                 (SELECT match.away_team_api_id  AS team_api_id,
                                         SUM(faults.away_faults) AS num_faults
                                  FROM match
                                           RIGHT JOIN faults ON match.match_api_id = faults.match_api_id
                                  WHERE match.season IN (SELECT season FROM last_3_seasons)
                                  GROUP BY match.away_team_api_id)) AS alias

                           GROUP BY team_api_id)
SELECT team_long_name AS "Club",
       total_faults   AS "Faltas",
       RANK () OVER (
            ORDER BY total_faults
           ) "Rank Faltas"
FROM team_total_faults ttf
         INNER JOIN dominant_teams dt ON ttf.team_api_id = dt.team_api_id
         INNER JOIN team t ON dt.team_api_id = t.team_api_id;
;

----------------------------------------
-- 9)
----------------------------------------
-- 1) ¿Cuál es la probabilidad de que un equipo E gane sus próximos partidos basándose en su historial de victorias en la última temporada?
-- 1.1) Identificar cual fué la ultima temporada h.
WITH last_season AS (SELECT DISTINCT season
                     FROM match
                     ORDER BY season DESC
                     LIMIT 1),
     last_3_seasons AS (SELECT DISTINCT season
                        FROM match
                        ORDER BY season DESC
                        LIMIT 3),

-- 1.2) Calcular el número total de partidos que el equipo E jugó en la ultima temporada
     team_matches AS (SELECT team_api_id, SUM(matches) as matches
                      FROM (SELECT home_team_api_id AS team_api_id, COUNT(*) AS matches
                            FROM match
                            WHERE season IN (SELECT * FROM last_season)
                            GROUP BY home_team_api_id
                            UNION ALL
                            SELECT away_team_api_id AS team_api_id, COUNT(*) AS matches
                            FROM match
                            WHERE season IN (SELECT * FROM last_season)
                            GROUP BY away_team_api_id) AS matches
                      GROUP BY team_api_id),

     -- 1.3) Calcular el número total de partidos que el equipo E ganó en la ultima temporada
     team_victories AS (SELECT team_api_id, SUM(victories) as victories
                        FROM (SELECT home_team_api_id AS team_api_id, COUNT(*) AS victories
                              FROM match
                              WHERE season IN (SELECT * FROM last_season)
                                AND home_team_goal > away_team_goal
                              GROUP BY home_team_api_id
                              UNION ALL
                              SELECT away_team_api_id AS team_api_id, COUNT(*) AS victories
                              FROM match
                              WHERE season IN (SELECT * FROM last_season)
                                AND away_team_goal > home_team_goal
                              GROUP BY away_team_api_id) AS vitories
                        GROUP BY team_api_id),
     average_last_3_season_victories AS (SELECT team_api_id, SUM(victories) / 3 as victories
                                         FROM (SELECT home_team_api_id AS team_api_id, COUNT(*) AS victories
                                               FROM match
                                               WHERE season IN (SELECT * FROM last_3_seasons)
                                                 AND home_team_goal > away_team_goal
                                               GROUP BY home_team_api_id
                                               UNION ALL
                                               SELECT away_team_api_id AS team_api_id, COUNT(*) AS victories
                                               FROM match
                                               WHERE season IN (SELECT * FROM last_3_seasons)
                                                 AND away_team_goal > home_team_goal
                                               GROUP BY away_team_api_id) AS vitories
                                         GROUP BY team_api_id),

-- 1.4) Calcular la proporción muestral de victorias en casa del equipo E en la última temporada (victories_muestral_proportion = home_victories/home_matches).
     victories_muestral_proportion AS (SELECT tm.team_api_id,
                                              (tv.victories / tm.matches::FLOAT) AS victories_muestral_proportion
                                       FROM team_matches tm
                                                JOIN team_victories tv
                                                     ON tm.team_api_id = tv.team_api_id)

SELECT t.team_long_name                                              as "Club",
       -- Probabilidad de que luego de ganar los seis primeros partidos ganen lo siguiente de la temporada
       ROUND((CUM_BIN_DIST_EQUAL_GREATER(tm.matches::INTEGER, al3sv.victories::INTEGER,
                                  vmp.victories_muestral_proportion) * 100)::NUMERIC, 2) AS "Cumulative probability: P(X≥average last 3 season victories)"
FROM victories_muestral_proportion vmp
         INNER JOIN dominant_teams dt
                    ON vmp.team_api_id = dt.team_api_id
         INNER JOIN average_last_3_season_victories al3sv
                    ON dt.team_api_id = al3sv.team_api_id
         INNER JOIN team_matches tm
                    ON dt.team_api_id = tm.team_api_id
         INNER JOIN team t
                    ON dt.team_api_id = t.team_api_id
WHERE t.team_long_name LIKE 'Paris Saint-Germain'
   OR t.team_long_name LIKE 'FC Bayern Munich'
    OR t.team_long_name LIKE 'FC Barcelona'
ORDER BY "Cumulative probability: P(X≥average last 3 season victories)"

