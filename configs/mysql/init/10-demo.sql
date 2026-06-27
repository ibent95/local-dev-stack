-- Demo data so tools (Hop, DBGate, Superset) have something to read in `app`.
-- Applied to the `app` database by scripts/run/mysql-init.* (DHI mysql ignores
-- /docker-entrypoint-initdb.d, so the init script runs these files instead).
-- Idempotent: CREATE ... IF NOT EXISTS + INSERT IGNORE on fixed primary keys.

CREATE TABLE IF NOT EXISTS demo_customers (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  email      VARCHAR(150) NOT NULL UNIQUE,
  country    CHAR(2)      NOT NULL DEFAULT 'ID',
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT IGNORE INTO demo_customers (id, name, email, country) VALUES
  (1, 'Andi Wijaya',    'andi@example.com',  'ID'),
  (2, 'Siti Rahmawati', 'siti@example.com',  'ID'),
  (3, 'John Carter',    'john@example.com',  'US'),
  (4, 'Mei Lin',        'mei@example.com',   'SG'),
  (5, 'Raka Pratama',   'raka@example.com',  'ID');

CREATE TABLE IF NOT EXISTS demo_orders (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT            NOT NULL,
  total       DECIMAL(10,2)  NOT NULL DEFAULT 0,
  status      VARCHAR(20)    NOT NULL DEFAULT 'pending',
  created_at  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_demo_orders_customer FOREIGN KEY (customer_id) REFERENCES demo_customers (id)
);

INSERT IGNORE INTO demo_orders (id, customer_id, total, status) VALUES
  (1, 1,  49.90, 'paid'),
  (2, 1,  12.00, 'paid'),
  (3, 2, 130.50, 'pending'),
  (4, 3,  8.75,  'shipped'),
  (5, 4, 220.00, 'paid'),
  (6, 5,  15.25, 'cancelled');
