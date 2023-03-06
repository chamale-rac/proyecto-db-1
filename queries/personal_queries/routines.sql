-- Probabilidad Binomial
create function bin_dist(n integer, x integer, p double precision) returns double precision
    language plpgsql
as
$$
BEGIN
    RETURN (FACTORIAL(n) / (FACTORIAL(n - x) * FACTORIAL(x))) * POWER(p, x) * POWER((1 - p), (n - x));
END;
$$;

-- Probabilidad Binomial Acumulada
alter function bin_dist(integer, integer, double precision) owner to postgres;

create function cum_bin_dist_equal_greater(n integer, x integer, p double precision) returns double precision
    language plpgsql
as
$$
DECLARE
    result DOUBLE PRECISION;
BEGIN
    SELECT SUM(bd)
    INTO result
    FROM (SELECT GENERATE_SERIES(x, n) AS i) series
             CROSS JOIN LATERAL
        BIN_DIST(n, i, p) AS bd;
    RETURN result;
END;
$$;

alter function cum_bin_dist_equal_greater(integer, integer, double precision) owner to postgres;

