CREATE TABLE faults (
    match_api_id TEXT,
    home_faults INTEGER,
    away_faults INTEGER
);

CREATE TABLE possession (
    match_api_id TEXT,
    home_possession NUMERIC,
    away_possession NUMERIC
);

CREATE TABLE goals (
    match_api_id TEXT,
    team_api_id TEXT,
    minute INTEGER
)