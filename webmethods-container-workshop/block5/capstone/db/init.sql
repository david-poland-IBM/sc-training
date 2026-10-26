-- Workshop business schema, executed once by the postgres image on first start
-- (anything in /docker-entrypoint-initdb.d runs only when the data volume is empty).
CREATE TABLE IF NOT EXISTS orders (
    id          BIGSERIAL PRIMARY KEY,
    customer    TEXT           NOT NULL,
    amount      NUMERIC(12, 2) NOT NULL,
    created_by  TEXT,
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT now()
);

INSERT INTO orders (customer, amount, created_by)
VALUES ('Swisscom Seed Customer', 42.00, 'init.sql');
